provider "aws" {
  region = "ap-south-1" # Update with your desired region
}

terraform {
  backend "s3" {
    bucket = "ecs-portfolio-terraform-state" # Replace with your S3 bucket name
    key    = "terraform.tfstate"             # Replace with your desired state file name
    region = "ap-south-1"                    # Replace with your desired AWS region

    # Optional: Uncomment the following lines if you want to enable encryption
    # encrypt        = true
    # kms_key_id     = "your-kms-key-id"  # Replace with your KMS key ID for encryption
    # dynamodb_table = "your-dynamodb-table-name"  # Replace with your DynamoDB table name for state locking
  }
}

# Create the ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.ecs_cluster_name # Replace with your desired cluster name
}

# Create the task definition
resource "aws_ecs_task_definition" "task_definition" {
  family                   = var.aws_ecs_task_definition_family_name # Replace with your desired task definition family name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu                = "256"
  memory             = "512"
  execution_role_arn = var.ecsTaskExecutionRole_arn

  container_definitions = <<DEFINITION
  [
    {
      "name": "my-container",
      "image": "345007036955.dkr.ecr.ap-south-1.amazonaws.com/jenkins-pipeline-image-build",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
}

# Create the Application Load Balancer
resource "aws_lb" "load_balancer" {
  name               = var.loadbalancer_name # Replace with your desired load balancer name
  load_balancer_type = "application"
  subnets            = var.subnets # Replace with your desired subnet IDs

  tags = {
    Name = var.loadbalancer_name # Replace with your desired load balancer name
  }
}

# Create the target group
resource "aws_lb_target_group" "target_group" {
  name        = var.target_group_name
  port        = var.target_group_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path = "/"
  }
}

#Create the listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = var.alb_listener_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target_group.arn
    type             = "forward"
  }
}

# Create the ECS service
resource "aws_ecs_service" "ecs_service" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets            # Replace with your desired subnet IDs
    security_groups  = var.security_group_ecs # Replace with your desired security group IDs
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "my-container"
    container_port   = 3000
  }

  depends_on = [aws_ecs_task_definition.task_definition]
}



# 2nd part of code

resource "aws_iam_role" "test_role" {
  name = "test_role_terraform"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({

    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
    },

  )

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.test_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

resource "aws_lambda_function" "update_ecs" {
  filename      = var.lambda_function_filename
  function_name = "update_ecs"
  role          = aws_iam_role.test_role.arn
  handler       = "python.lambda_function.lambda_handler"
  runtime       = "python3.9"
}

resource "aws_cloudwatch_event_rule" "ecr_push_rule" {

  event_bus_name = "default"
  event_pattern = jsonencode(
    {
      detail = {
        action-type = [
          "PUSH",
        ],
        result          = ["SUCCESS"],
        repository-name = ["jenkins-pipeline-image-build"]
      }
      detail-type = [
        "ECR Image Action",
      ]
      source = [
        "aws.ecr",
      ]
    }
  )
  is_enabled = true
  name       = "updateecsservice2"
  tags       = {}
  tags_all   = {}
}

resource "aws_cloudwatch_event_target" "update_ecs_target" {
  rule      = aws_cloudwatch_event_rule.ecr_push_rule.name
  target_id = "update_ecs"
  arn       = aws_lambda_function.update_ecs.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_update_ecs" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_ecs.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecr_push_rule.arn
}
