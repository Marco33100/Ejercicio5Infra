# IP pública de quien ejecuta Terraform, para limitar SSH a esa máquina.
data "http" "mi_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  admin_cidr = coalesce(var.admin_cidr, "${chomp(data.http.mi_ip.response_body)}/32")
}

data "aws_vpc" "default" {
  default = true
}

# Ubuntu 24.04 LTS oficial de Canonical.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Llave SSH generada por Terraform; la privada solo se guarda en .ssh/ (ignorado por Git) y en el estado local.
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "deployer" {
  key_name   = "ejercicio5-deployer"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "ssh_private_key" {
  filename        = "${path.module}/../.ssh/ejercicio5.pem"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

resource "aws_security_group" "app" {
  name        = "ejercicio5-app"
  description = "SSH solo desde la IP del administrador; HTTP publico para el cliente web"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH administrador"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.admin_cidr]
  }

  ingress {
    description = "Cliente web"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida a Internet (paquetes, GitHub, Docker Hub)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.app.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "ejercicio5-app" }
}

# Inventario que consume Ansible; la ruta de la llave es la del contenedor de herramientas.
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = <<-EOT
    [app]
    ${aws_instance.app.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/ejercicio5.pem
  EOT
}
