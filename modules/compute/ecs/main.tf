resource "aws_ecs_cluster" "main" {
  name  = "${var.project}-ecs-cluster-${var.env}"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
