output "ec2_public_ip" {
  value = aws_instance.bench.public_ip
}

output "ec2_ssh_command" {
  value = "ssh -i /path/to/${var.ec2_key_name}.pem ec2-user@${aws_instance.bench.public_ip}"
}

output "docdb_endpoint" {
  value = aws_docdb_cluster.this.endpoint
}

output "docdb_port" {
  value = aws_docdb_cluster.this.port
}

# Paste this into your Go / app after replacing <password>.
output "docdb_connection_string" {
  value = "mongodb://${var.docdb_master_username}:<password>@${aws_docdb_cluster.this.endpoint}:${aws_docdb_cluster.this.port}/?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
}

# One-liner to run once you're SSH'd into the EC2. mongosh + CA bundle
# are already installed by user_data; the helper script sits in ~ec2-user.
output "docdb_mongosh_command" {
  value = "./connect.sh -p '<password>'"
}

