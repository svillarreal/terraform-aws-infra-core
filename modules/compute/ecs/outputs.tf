output "ecs_cluster_arn" {
    value = aws_ecs_cluster.main.arn
    description = "ECS Cluster ARN"
}