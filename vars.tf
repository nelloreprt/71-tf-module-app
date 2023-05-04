variable "instance_type" {}
variable "component" {}
variable "env" {}
variable "tags" {}
variable "desired_capacity" {}
variable "max_size" {}
variable "min_size" {}
variable "subnets" {}

variable "vpc_id" {}
variable "bastion_cidr" {}

variable "port" {}
variable "allow_app_to" {}

variable "dns_domain" {}

variable "alb_dns_domain" {}

variable "listener_arn" {}

variable "listener_priority" {}