terraform {
  backend "s3" {
    bucket = "terraform-remote-state-svillarreal"
    key    = "terraform-aws-infra-core/dev"
    region = "us-east-1"
  }
}
