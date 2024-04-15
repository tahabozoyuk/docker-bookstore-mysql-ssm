terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}


# Configure the GitHub Provider
provider "github" {
    token = data.aws_ssm_parameter.token.value
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}



variable "key-name" {
  default = "esra"
}

data "aws_ssm_parameter" "token" {
  name = "git-token"
}

data "aws_ssm_parameter" "gitname" {
  name = "git-name"
}


resource "aws_instance" "tf-docker-ec2" {
  ami = "ami-051f8a213df8bc089"
  instance_type = "t2.micro"
  key_name = var.key-name
  vpc_security_group_ids = [aws_security_group.tf-docker-sec-gr.id]
  tags = {
    Name = "Web Server of Bookstore"
  }
  user_data = templatefile("user-data.sh", { user-data-git-token = data.aws_ssm_parameter.token.value, user-data-git-name = data.aws_ssm_parameter.gitname.value })
  depends_on = [ github_repository.myrepo, github_repository_file.app-files ]

}

resource "github_repository" "myrepo" {
  name        = "bookstore-api-repo"
  description = "My app"
  visibility = "private"
  auto_init = true
}
resource "github_branch_default" "default"{
  repository = github_repository.myrepo.name
  branch     = "main"
}
variable "files" {
  default = ["bookstore-api.py", "docker-compose.yml", "requirements.txt", "Dockerfile"]
}

resource "github_repository_file" "app-files" {
  for_each            = toset(var.files)
  file                = each.value
  content             = file(each.value)
  repository          = github_repository.myrepo.name
  branch              = github_branch_default.default.branch
  commit_message      = "Managed by Terraform"
  commit_author       = "tahabozoyuk"
  commit_email        = "tahabozoyuk@gmail.com"
  overwrite_on_create = true
}

resource "aws_security_group" "tf-docker-sec-gr" {
  name = "docker-sec-gr-203"
  tags = {
    Name = "docker-sec-group-203"
  }
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}



output "website" {
  value = "http://${aws_instance.tf-docker-ec2.public_dns}"
}