variable "project_id" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "name_prefix" { type = string }
variable "vpc_name" { type = string }
variable "subnet_name" { type = string }

# GPU pool sizing
variable "gpu_machine_type" { type = string default = "g2-standard-8" } # TODO adjust
variable "gpu_count_per_node" { type = number default = 1 }
variable "gpu_min_nodes" { type = number default = 0 }
variable "gpu_max_nodes" { type = number default = 3 }
