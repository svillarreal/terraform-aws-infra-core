variable "project" {
  default = "timeservice"
}

variable "env" {
  default = "dev"
}

variable "ecr_name" {
  type        = string
  description = "ECR Repo Name"
  default     = "timeservice-ecr"
}