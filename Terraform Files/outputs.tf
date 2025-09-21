output "oiseoje-web-server_ip" {
  value       = aws_instance.oiseoje-web-server.public_ip
  description = "Public IP of the web server"
}

output "web_url" {
  value       = "http://${aws_instance.oiseoje-web-server.public_ip}:${var.web_port}"
  description = "HTTP URL for quick test"
}
