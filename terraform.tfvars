# Region & AZ's
region             = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]
# Instance details
instance_count     = 2
instance_type      = "t2.micro"
generated_key_pair = "terraform-key-pair"
# For Security Group Ingress & Egress
http_port = 80
ssh_port  = 22
# To allow your ip in Security group ingress to access EC2
myip = ["116.15.129.96/32"]