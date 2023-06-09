ecs_cluster_name                    = "my-ecs-cluster"
ecsTaskExecutionRole_arn            = "arn:aws:iam::345007036955:role/ecsTaskExecutionRole"
aws_ecs_task_definition_family_name = "my-task-definition"
loadbalancer_name                   = "my-load-balancer"
subnets                             = ["subnet-00e0797a6891f1328", "subnet-0a9d4f168b16e560c"]
security_group_ecs                  = ["sg-074e3966bfedcf38c"]
vpc_id                              = "vpc-0b3c69334e312403c"
target_group_name                   = "my-target-group"
target_group_port                   = 3000
alb_listener_port                   = 80
ecs_service_name                    = "my-ecs-service"
ecs_container_port                  = 3000
lambda_function_filename            = "python.zip"
