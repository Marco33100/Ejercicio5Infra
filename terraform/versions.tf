terraform {
  required_version = ">= 1.6"

  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.0" }
    tls   = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.5" }
    http  = { source = "hashicorp/http", version = "~> 3.4" }
  }
}

# Credenciales: AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY llegan como variables de entorno desde secrets.env.
provider "aws" {
  region = var.region

  default_tags {
    tags = { Proyecto = "Ejercicio5", GestionadoPor = "Terraform" }
  }
}
