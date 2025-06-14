output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.flask_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.flask_eip.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.flask_server.public_dns
}

output "elastic_ip" {
  description = "Elastic IP address"
  value       = aws_eip.flask_eip.public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.flask_sg.id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/tom.pem ubuntu@${aws_eip.flask_eip.public_ip}"
}

output "application_urls" {
  description = "URLs to access the application"
  value = {
    nginx_url = "http://${aws_eip.flask_eip.public_ip}"
    flask_url = "http://${aws_eip.flask_eip.public_ip}:5000"
  }
}