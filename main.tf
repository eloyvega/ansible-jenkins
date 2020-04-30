provider "aws" {
  region = var.region
}

locals {
  key_path = "${path.module}/${var.key_name}.pem"
}

resource "aws_default_vpc" "default" {}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "SSH from everywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "8080 from everywhere"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins"
  }
}

resource "aws_instance" "jenkins_server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  tags = {
    Name = "JenkinsServer"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ec2-user"
      private_key = file(local.key_path)
    }
  }

  provisioner "local-exec" {
    command = "echo '${self.public_ip}' > ./inventory"
  }

  provisioner "local-exec" {
    command = "ansible-playbook --private-key=${local.key_path} bootstrap.yml"
  }
}

output "JenkinsURL" {
  value = "${aws_instance.jenkins_server.public_dns}:8080"
}

output "SSH_info" {
  value = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.jenkins_server.public_ip}"
}
