provider "aws" {
  region = "us-east-2"
}

data "aws_availability_zones" "all" {}


resource "aws_instance" "example" {
  ami                    = "ami-0c55b159cbfafe1f0"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = <<EOF
#!/bin/bash
echo "Hello there!" > index.html
nohup busybox httpd -f -p "${var.server_port}" &
EOF

  key_name = aws_key_pair.deployer.key_name

  tags = {
    Name = "terraform-example"
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  # Allow all inbound to 8080
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDGWLMnKGdj921lYk7gK8NrSbH5zZT8VgFud0Jp+eVgdlg+pE76htnwz82E8CqMXQknnr8xicSxFZA9i5mMgeiXdAD6lk0Xo/xXmFXm7zFJjepqi8UpMc4UHC4Kfu6yt5b/YMbMJu5u0YROLwDjgHQykb8MwC+Yy8l8o3sltqVmSbqxI/sMhT+22NnrxmQ8zWiAHl71GgVvumiI9gABrLkBGc79cMXHCB5J3UTby6g4dqmQ4LxZoA5izWsWQMFqd0Oh4ClQO3nmWFS30nR9p5P71dRky1LkRzOaRhi5RESCyAGiA2uw6cI4tdqGSINjw+oueTmmsPOpn0SiwVJC0xpr duliu@192-168-1-14.tpgi.com.au"
}

resource "aws_security_group" "elb" {
  name = "terraform-example-elb"

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_launch_configuration" "example" {
  image_id        = "ami-0c55b159cbfafe1f0"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<EOF
#!/bin/bash
echo "Hello there!" > index.html
nohup busybox httpd -f -p "${var.server_port}" &
EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.id
  availability_zones   = data.aws_availability_zones.all.names

  min_size = 2
  max_size = 5

  load_balancers    = [aws_elb.example.name]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_elb" "example" {
  name               = "terraform-asg-example"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = data.aws_availability_zones.all.names

  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}