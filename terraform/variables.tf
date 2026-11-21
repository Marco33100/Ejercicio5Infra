variable "region" {
  # La cuenta del plan gratuito tiene una SCP de organización que bloquea EC2 en us-east-1.
  description = "Región de AWS donde se crea la VM."
  type        = string
  default     = "us-east-2"
}

variable "instance_type" {
  description = "Tipo de VM. m7i-flex.large (2 vCPU, 8 GB) es elegible para el plan gratuito de cuentas creadas desde el 15/07/2025."
  type        = string
  default     = "m7i-flex.large"
}

variable "admin_cidr" {
  description = "Rango autorizado para SSH. Si es null se usa la IP pública de quien ejecuta Terraform."
  type        = string
  default     = null
}
