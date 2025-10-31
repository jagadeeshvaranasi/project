output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.ubuntu.id
}

output "public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.ubuntu.public_ip
}

output "private_key_file" {
  description = "Path to the private key file generated locally"
  value       = local_file.private_key_pem.filename
}
