# provider "aws" {
#   region = "us-east-1"
# }


##############backend

# terraform {
#   backend "s3" {
#     # Replace this with your bucket name!
#     bucket         = "terraform-up-and-running-statech"
#     key            = "stage/webserver/terraform.tfstate"
#     region         = "us-east-1"

#     # Replace this with your DynamoDB table name!
#     dynamodb_table = "terraform-up-and-running-locks"
#     encrypt        = true
#   }
# }


##############locals

locals {
  http_port    = 80
  # any_port     = 0
  # any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}

##############resources

resource "aws_launch_configuration" "example" {
  image_id        = "ami-0b9a603c10937a61b"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

# Required when using a launch configuration with an auto scaling group.
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "instance" {

  name = "${var.cluster_name}-sg"

  ingress {
    cidr_blocks = local.all_ips
    description = "allow 8080 for public"
    from_port = var.server_port
    protocol = local.tcp_protocol
    to_port = var.server_port
  } 
  
}

resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"

  # Allow inbound HTTP requests
  ingress {
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.all_ips
  }
}


resource "aws_lb" "example" {
  name               = "${var.cluster_name}-terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_target_group" "asg" {
  name     = "${var.cluster_name}-terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

#######data
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

