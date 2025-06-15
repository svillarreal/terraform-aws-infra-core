output "timeservice_url" {
  value       = aws_lb.timeservice_alb.dns_name
  description = "TimeService Public Service URL"
}
