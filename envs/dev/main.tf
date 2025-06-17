locals {
  ecr_name = "${var.project}-ecr-repo-${var.env}"
}

module "timeservice_vpc" {
  source = "../../modules/network/vpc"
}

module "timeservice_ecs_cluster" {
  source  = "../../modules/compute/ecs"
  project = var.project
  env     = var.env
}

resource "aws_ecr_repository" "timeservice_ecr" {
  name         = local.ecr_name
  force_delete = true
  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_iam_role" "timeservice_task_ecr_role" {
  name = "${var.project}-task-ecr-role-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "timeservice_task_execution_role" {
  name = "${var.project}-task-execution-role-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "timeservice_iam_policy_attachement" {
  role       = aws_iam_role.timeservice_task_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "timeservice_iam_execution_role_policy_attachement" {
  role       = aws_iam_role.timeservice_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "timeservice_task" {
  family = "${var.project}-ecs-task-definition-${var.env}"
  requires_compatibilities = [
    "FARGATE",
  ]

  container_definitions = jsonencode([
    {
      name  = local.ecr_name
      image = "851717133722.dkr.ecr.us-east-1.amazonaws.com/timeservice-ecr-repo-dev:b70a2ac3e988aed5febddf26c04569117397ab34"
      cpu   = 256
      log_configuration = {
        log_driver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project}-ecs-task-definition-${var.env}"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      memory = 512
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
    }
  ])
  cpu                = 256
  memory             = 512
  network_mode       = "awsvpc"
  task_role_arn      = aws_iam_role.timeservice_task_ecr_role.arn
  execution_role_arn = aws_iam_role.timeservice_task_execution_role.arn
}

resource "aws_security_group" "timeservice_sg" {
  name        = "${var.project}-sg-${var.env}"
  description = "AWS Security Group for TimeService ECS Fargate endpoint"
  vpc_id      = module.timeservice_vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "eighteen_ingress_rule" {
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.timeservice_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "timeservice_ingress_rule" {
  from_port         = 3000
  to_port           = 3000
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.timeservice_sg.id
}

resource "aws_vpc_security_group_egress_rule" "https_egress_rule" {
  security_group_id = aws_security_group.timeservice_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
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
  port        = 3000
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
    container_name   = local.ecr_name
    container_port   = 3000
  }

  network_configuration {

    subnets          = [module.timeservice_vpc.main_private_subnet_id, module.timeservice_vpc.secondary_private_subnet_id]
    security_groups  = [aws_security_group.timeservice_sg.id]
    assign_public_ip = false
  }

  desired_count = 1
  depends_on    = [aws_lb_listener.timeservice_aws_lb_listener]
}
