resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key_pem" {
  content  = tls_private_key.key.private_key_pem
  filename = "${path.module}/${var.key_name_prefix}.pem"
  file_permission = "0600"

}

resource "aws_key_pair" "generated" {
  key_name   = var.key_name_prefix
  public_key = tls_private_key.key.public_key_openssh
}

# Use default VPC and first available public subnet (internet enabled)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  subnet_id = data.aws_subnets.default_vpc.ids[0]
}

resource "aws_security_group" "instance_sg" {
  name        = "devsecops-instance-sg"
  description = "Allow SSH, HTTP and 8000-8010 TCP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
# For docker vault UI
  ingress {
    description = "vault"
    from_port   = 8400
    to_port     = 8400
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "App range"
    from_port   = 8000
    to_port     = 8010
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
  depends_on = []
}

resource "aws_instance" "ubuntu" {
  ami                    = var.instance_ami != "" ? var.instance_ami : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  # Root volume configuration: 15 GB
  root_block_device {
    volume_size = 25
    volume_type = "gp3"
    delete_on_termination = true
  }
  subnet_id              = local.subnet_id
  associate_public_ip_address = true
  key_name               = aws_key_pair.generated.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  #user_data = templatefile("${path.module}/userdata1.tpl", {})

  tags = {
    Name = "devsecops-ubuntu"
  }
  depends_on = [local_file.private_key_pem]
}


resource "null_resource" "Install_docker" {

    connection {
      type        = "ssh"
      host        = aws_instance.ubuntu.public_ip
      user        = "ubuntu"
      private_key = tls_private_key.key.private_key_pem
    }
  # Copy and run script
  provisioner "file" {
    source      = "install_docker.sh"
    destination = "/tmp/install_docker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_docker.sh",
      "sudo bash /tmp/install_docker.sh"
    ]
  }

  depends_on = [aws_instance.ubuntu]
}


resource "null_resource" "wait_for_ssh" {

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.ubuntu.public_ip
      user        = "ubuntu"
      private_key = tls_private_key.key.private_key_pem
    }

    inline = [
      "sleep 60",
      "echo 'install OpenJDK 17...'",
      "sudo apt update && sudo apt upgrade -y",
      "sudo apt install -y openjdk-17-jdk",
      "java -version",
      "sleep 50",
      "### Trivy installation",
      "sudo apt-get install wget gnupg",
      "wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null",
      "echo \"deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main\" | sudo tee -a /etc/apt/sources.list.d/trivy.list",
      "sudo apt-get update",
      "sudo apt-get install trivy -y",
      "sleep 50",
      "echo 'Trivy installed successfully.'",
      "echo 'Install dependencies.'",
      "sudo apt update && sudo apt install -y git curl wget unzip zip jq gnupg ca-certificates  software-properties-common apt-transport-https",
      "echo 'Creating directory for agent'",
      "sleep 50",
      "echo 'Installing Python3, pip, Docker...'",
      "sudo apt update",
      "sudo apt install -y python3 python3-pip",
      "sudo usermod -aG docker jenkins",
      "sudo apt install python3.10-venv -y",
      "mkdir -p /home/ubuntu/jenkins",
      "sleep 50",
      "sudo chmod 666 /var/run/docker.sock",
      "mkdir -p ~/prom-grafana || true"
    ]
  }

  depends_on = [null_resource.Install_docker]
}

resource "null_resource" "prom_grafana_stack" {

    connection {
      type        = "ssh"
      host        = aws_instance.ubuntu.public_ip
      user        = "ubuntu"
      private_key = tls_private_key.key.private_key_pem
    }
  # Copy and run script
  provisioner "file" {
    source      = "docker-compose.yml"
    destination = "/home/ubuntu/prom-grafana/docker-compose.yml"
  }

  provisioner "file" {
    source      = "prometheus.yml"
    destination = "/home/ubuntu/prom-grafana/prometheus.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/ubuntu/prom-grafana",
      "docker compose -f docker-compose.yml up -d",
      "sleep 50"
    ]
  }

  depends_on = [null_resource.wait_for_ssh]
}


# resource "null_resource" "sonarqube_setup" {

#   connection {
#       type        = "ssh"
#       host        = aws_instance.ubuntu.public_ip
#       user        = "ubuntu"
#       private_key = tls_private_key.key.private_key_pem
#     }
#   # Copy and run script
#   provisioner "file" {
#     source      = "install_sonarqube.sh"
#     destination = "/tmp/install_sonarqube.sh"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "chmod +x /tmp/install_sonarqube.sh",
#       "sudo bash /tmp/install_sonarqube.sh"
#     ]
#   }

#   depends_on = [null_resource.wait_for_ssh]
# }

resource "jenkins_credential_ssh" "agent_ssh" {
  name        = var.jenkins_key_name
  description = var.jenkins_key_name
  username    = "ubuntu"
  #privatekey  = file("${var.key_name_prefix}.pem")
  privatekey = tls_private_key.key.private_key_pem
  depends_on = [local_file.private_key_pem, null_resource.wait_for_ssh]
}

resource "jenkins_node" "ubuntu_agent" {
  name               = var.agent_name
  description        = "Terraform-created Jenkins agent"
  remote_root_directory = "/home/ubuntu/jenkins"

  labels             = ["vish-security-agent"]
  port          = 22
  credential_name = jenkins_credential_ssh.agent_ssh.name
  ip            = aws_instance.ubuntu.public_ip
  depends_on = [jenkins_credential_ssh.agent_ssh]
}
