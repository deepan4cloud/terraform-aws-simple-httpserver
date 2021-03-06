# Region & AZ's
region             = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]

# Instance details
instance_count     = 2
instance_type      = "t2.micro"
generated_key_pair = "terraform-key-pair"

# For Security Group Ingress & Egress
http_port = 8888      ## This will also be the webserver running port / ingress port to ALB #
http_protocol = "HTTP"

# To allow your ip in Security group ingress to access EC2. 
# Use https://www.whatismyip.com/ to find your ip.
myip = ["116.15.129.96/32"]

## Application name. This will be used in tags to name resources ##
appname = "SS"