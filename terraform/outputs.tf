output "ip_publica" {
  value = aws_instance.app.public_ip
}

output "url_cliente" {
  value = "http://${aws_instance.app.public_ip}"
}

output "url_grafana" {
  value = "http://${aws_instance.app.public_ip}:3000"
}

output "ssh" {
  value = "ssh -i .ssh/ejercicio5.pem ubuntu@${aws_instance.app.public_ip}"
}

output "ssh_permitido_desde" {
  value = local.admin_cidr
}
