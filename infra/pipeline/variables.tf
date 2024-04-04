

variable "codebuild_role_arn" {
  default = ""
}

variable "task_execution_role_arn" {
  default = ""
}

variable "codedeploy_svc_role_arn" {
  default = ""
}

variable "ecs_cluster_name" {
  default = ""
}

variable "ecs_service_name" {
  default = ""
}

variable blue_listener_arn {
  default=""
}

variable green_listener_arn {
  default=""
}

variable "blue_target_group_name" {
  default=""
}

variable "green_target_group_name" {
  default=""
}

variable "lb_name"{
  default=""
}

variable "codedeploy_service_role_arn" {
  default = ""
}


variable "code_pipeline_role" {
  default = ""
}

variable "code_pipeline_source_role" {
  default = ""
}

variable "code_pipeline_build_role" {
  default = ""
}

variable "code_pipeline_deploy_role" {
  default = ""
}

variable "events_role_arn" {
  default = ""
}