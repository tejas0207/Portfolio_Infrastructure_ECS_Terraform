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
  name = "my-ecs-cluster" # Replace with your desired cluster name
}

# Create the task definition
resource "aws_ecs_task_definition" "task_definition" {
  family                   = "my-task-definition" # Replace with your desired task definition family name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu                = "256"
  memory             = "512"
  execution_role_arn = "arn:aws:iam::345007036955:role/ecsTaskExecutionRole" # Add the CPU value here

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
  name               = "my-load-balancer" # Replace with your desired load balancer name
  load_balancer_type = "application"
  subnets            = ["subnet-00e0797a6891f1328", "subnet-0a9d4f168b16e560c"] # Replace with your desired subnet IDs

  tags = {
    Name = "my-load-balancer" # Replace with your desired load balancer name
  }
}

# Create the target group
resource "aws_lb_target_group" "target_group" {
  name        = "my-target-group" # Replace with your desired target group name
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = "vpc-0b3c69334e312403c"
  target_type = "ip" # Replace with your desired VPC ID

  health_check {
    path = "/"
  }
}

#Create the listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target_group.arn
    type             = "forward"
  }
}

# Create the ECS service
resource "aws_ecs_service" "ecs_service" {
  name            = "my-ecs-service" # Replace with your desired service name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-00e0797a6891f1328", "subnet-0a9d4f168b16e560c"] # Replace with your desired subnet IDs
    security_groups  = ["sg-074e3966bfedcf38c"]                                 # Replace with your desired security group IDs
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
  filename      = "python.zip"
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
