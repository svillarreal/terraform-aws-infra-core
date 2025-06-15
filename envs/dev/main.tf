module "timeservice_vpc" {
  source = "../../modules/network/vpc"
}

module "timeservice_ecs_cluster" {
  source  = "../../modules/compute/ecs"
  project = var.project
  env     = var.env
}

resource "aws_ecr_repository" "timeservice_ecr" {
  name         = "${var.project}-${var.ecr_name}-${var.env}"
  force_delete = true
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_task_definition" "timeservice_task" {
  family = "${var.project}-ecs-task-definition-${var.env}"
  requires_compatibilities = [
    "FARGATE",
  ]
  container_definitions = jsonencode([
    {
      name   = "${var.project}-ecs-task-definition-${var.env}"
      cpu    = 2
      memory = 512
      image  = "latest"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  cpu          = 2
  memory       = 512
  network_mode = "awsvpc"
}

resource "aws_security_group" "timeservice_sg" {
  name        = "${var.project}-sg-${var.env}"
  description = "AWS Security Group for TimeService ECS Fargate endpoint"
  vpc_id      = module.timeservice_vpc.vpc_id
  ingress {
    description = "allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.timeservice_vpc.vpc_cidr]
  }

}

resource "aws_lb" "timeservice_alb" {
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.timeservice_sg.id
  ]
  name     = "${var.project}-alb-${var.env}"
  internal = false
  subnets = [module.timeservice_vpc.main_public_subnet_id,
    module.timeservice_vpc.secondary_public_subnet_id
  ]
  depends_on = [module.timeservice_vpc]
}

resource "aws_lb_target_group" "timeservice_alb_target_group" {
  name        = "${var.project}-ts-alb-tg-${var.env}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.timeservice_vpc.vpc_id
  target_type = "ip"

}

resource "aws_lb_listener" "timeservice_aws_lb_listener" {
  load_balancer_arn = aws_lb.timeservice_alb.arn
  protocol          = "HTTP"
  port              = 80
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.timeservice_alb_target_group.arn
  }

}

resource "aws_ecs_service" "timeservice_service" {
  name             = "${var.project}-ecs-service-${var.env}"
  task_definition  = aws_ecs_task_definition.timeservice_task.arn
  cluster          = module.timeservice_ecs_cluster.ecs_cluster_arn
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  load_balancer {
    target_group_arn = aws_lb_target_group.timeservice_alb_target_group.arn
    container_name   = "timeservice"
    container_port   = 80
  }

  network_configuration {

    subnets          = [module.timeservice_vpc.main_public_subnet_id, module.timeservice_vpc.secondary_public_subnet_id]
    security_groups  = [aws_security_group.timeservice_sg.id]
    assign_public_ip = true
  }

  desired_count = 1
}
