
variable "ecs_cluster_name" {
  type = string

}
variable "ecsTaskExecutionRole_arn" {
  type = string

}
variable "aws_ecs_task_definition_family_name" {
  type = string

}
variable "loadbalancer_name" {
  type = string

}
variable "subnets" {
  type = list(string)

}
variable "security_group_ecs" {
  type = list(string)

}
variable "vpc_id" {
  type = string

}
variable "target_group_name" {
  type = string

}
variable "target_group_port" {
  type = number

}
variable "alb_listener_port" {
  type = number

}
variable "ecs_service_name" {
  type = string

}
variable "ecs_container_port" {
  type = number

}
variable "lambda_function_filename" {
  type = string

}
