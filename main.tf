provider "aws" {
 shared_credentials_file = "/home/student/.aws/credentials"
 profile = "roi"
 region ="us-east-1"
}

resource "aws_key_pair" "mera" {
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDb2fUlXI4q9EPI+IutLoztht86L3WtApYkGe38MYxm5HobEJ8OK3q20cy5b1ExzCNzP8JznJCFUW4NaqpZq46KJSqAT1NaxG/D4H6pVJReRLCjfDh3zpSs0nwUWWPYRANj2tDRhXK557b1btxW9PQ9IGYpJ3E/rLubn4CHTwrwTDMVT/qd1nPrgwF5yr7UL468RumSnsAcmH3ZJMypBDRaTMpkpnxSUQjWH8/Uf3nqXkK4oprKYOIcZOfcmRGOjpFFjOutG2aDabmfhoXgeWvwzlqMmPiFhhmTvQrJwDcN4Sq2rj8V23N5xihm42LveeQEwpqyJCUt94UbaRlf449v student@a627953-linux"
  key_name = "mera"
}
# resource "aws_ecs_service" "ecss"{
#   name = "nginx"
#   task_definition = ""
#   desired_count = 3
#   cluster = "${aws_ecs_cluster.ecsc.id}"

#   lifecycle {
#     ignore_changes = ["desired_count"]
#   }
# }

resource "aws_ecs_cluster" "ecsc" {
  name = "nginx-cluster"
}

data "aws_iam_role" "ecsaccess" {
  name = "ec2ecs"
}

# output "name" {
#   value = "${aws_instance.example.*.public_dns}"
# }
resource "aws_security_group" "docker_alb" {
  name = "docker alb"
  ingress {
    from_port = 80
    to_port = 80
    protocol ="tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8
    to_port = 0
    protocol ="icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "publica"{
  
  name = "docker instances"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    security_groups = ["${aws_security_group.docker_alb.id}"]
    
  }

  egress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}

# resource "aws_ecs_task_definition" "ecstask"{
  
# }
data "template_file" "env"{
  template = <<-EOF
  #!/bin/bash
  echo 'ECS_CLUSTER=${aws_ecs_cluster.ecsc.name}' >> /etc/ecs/ecs.config
  EOF
}
resource "aws_launch_template" "lconfig"{
  image_id           = "ami-0b9a214f40c38d5eb"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.publica.id}"]
  iam_instance_profile = {
    name = "${data.aws_iam_role.ecsaccess.name}"
  }
  user_data = "${base64encode(data.template_file.env.rendered)}"
  
  key_name = "mera"

  lifecycle {
    create_before_destroy = true
  }
}
data "aws_availability_zones" "avail" {}
resource "aws_autoscaling_group" "asg1" {
  name = "ecsasg"
  availability_zones = ["${data.aws_availability_zones.avail.names}"]
  launch_template = {
    id = "${aws_launch_template.lconfig.id}"
    version ="$$Latest"
  }
  health_check_grace_period = 30
  default_cooldown = 30
  health_check_type = "ELB"
  target_group_arns = ["${aws_lb_target_group.docker-alb-tg.id}"]
  min_size = 2
  max_size = 5
  lifecycle {
    create_before_destroy = true
  }

}
resource "aws_default_vpc" "default_vpc" {
  
}

data "aws_subnet_ids" "subid"{
  vpc_id = "${aws_default_vpc.default_vpc.id}"
}
resource "aws_lb" "docker-alb" {
  name = "docker-alb"
  load_balancer_type = "application"
  internal = false
  security_groups = ["${aws_security_group.docker_alb.id}"]
  subnets = ["${data.aws_subnet_ids.subid.ids}"]
}

resource "aws_lb_listener" "docker-alb-lis" {
  load_balancer_arn = "${aws_lb.docker-alb.id}"
  port = "80"

  default_action{
    type = "forward"
    target_group_arn = "${aws_lb_target_group.docker-alb-tg.id}"
  }

  
}

resource "aws_lb_target_group" "docker-alb-tg" {
  name = "docker-lb-grp"
  port = "8080"
  protocol ="HTTP"
  vpc_id = "${aws_default_vpc.default_vpc.id}"

}

