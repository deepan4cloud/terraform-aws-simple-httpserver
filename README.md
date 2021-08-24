# **Terraform-EC2-with-Python_HTTPServer-behind-ALB**

***
### **This task is about:**
#### * Creating 2 EC2 instances on default VPC of the account A in us-east-1 region
#### * Run installation of a simple web-server(e.g. python http.server) on each of the instances
#### * Make web-server available from public Internet through Application Load Balancer
#### * Adhering best-practices.
***
## **Files:**

* [main.tf](https://github.com/deepan4cloud/terraform-aws-simple-httpserver/blob/master/main.tf) - Launches EC2 instances, security groups, Application loadbalancer, Loadbalancer Target Group and User-data to launch Python webserver
* [variables.tf](https://github.com/deepan4cloud/terraform-aws-simple-httpserver/blob/master/variables.tf) - Used by other files, sets default AWS region, calculates availability zones, etc.
* [terraform.tfvars](https://github.com/deepan4cloud/terraform-aws-simple-httpserver/blob/master/terraform.tfvars) - Actual variable file with user inputs. Terraform will provision the resources based on these variables. Please update as you wish.
* [webserver.py](webserver.py) - Python code to run HTTP.Server, running in port # 80.
* [index.html](https://github.com/deepan4cloud/terraform-aws-simple-httpserver/blob/master/index.html) - Simple web page to load when python HTTP server runs.
* [outputs.tf](https://github.com/deepan4cloud/terraform-aws-simple-httpserver/blob/master/outputs.tf) - It will fetch the ALB DNS name to access the web page along with EC2 instance Public_ip to access over ssh.

### Note: 

    This Terraform code will make use of existing VPC in the region (default VPC) and it's subnets. This code will not create new VPC/Subnets/Routetables/NACL's.

    Also, running "terraform destroy" after creating other resources will not delete those existing resources used in this code. ex: VPC, Subnet, NACL, IGW..,

***
### Points to note before running "terraform apply"

    1) This TF code uses "S3" as the remote backend. Please create/use your own bucket in "S3" and update the bucket name in "main.tf" file under "terraform backend" block.

    2) If you want to override the backed S3 configuration, please run "terraform init" with below options.

       terraform init \
       -backend-config="bucket=${Your bucket name}" \
       -backend-config="key=${Your key name}" \
       -backend-config="region=${Your region}"

    3) If you don't want to use remote backend but local backend, please remove/comment out "terraform backend" block in "main.tf" file.
       un-comment local backend block.

    4) This code uses, "us-east-1" region and "us-east-1a" & "us-east-1b" AZ's, One instance in each AZ, with "t2.micro" as instance type.
       To override these parameters, please update "terraform.tfvars"

    5) Two security groups will be created, One for ALB & one for EC2 instance.
       As a best practice:
           ALB security group will only allow port# 80 as ingress. All other ports will be denied. 
           EC2 security group will only port# 80 ingress from ALB security group and port# 22 SSH only from my ip. All other ports/IP's will be denied.
       To access EC2 instances post provisioning, please update "myip" parameter in "terraform.tfvars"

    6) This code will create a new EC2 key_pair and attach it to the EC2 instances, and download a copy of it locally in your present dir for your use.
       Please use it wisely.

    7) Have not used "modules" method of terraform coding as it is a straight forward resource creation using existing VPC. :)

***
## Prerequisite:

    1) Terraform installed
    2) AWS_Access_key & AWS_secret_access_key passed on as environment variables.

## How to Use:

    1) Create S3 bucket for remote backend. Update backend information in `main.tf` [If you don't want to use remote backend but local backend, please remove/comment out "terraform backend" block in "main.tf" file.
       un-comment local backend block.]
    2) git clone https://github.com/deepan4cloud/terraform-aws-simple-httpserver.git && cd terraform-aws-simple-httpserver
    3) Update "terraform.tfvars" as per your needs
    2) terraform init
    3) terraform plan
    4) terraform apply

    Output block will show below outputs:
    ex:
    Outputs:
        alb-dns = "ss-alb-2119877894.us-east-1.elb.amazonaws.com" -> Use this DNS name to access the web page. Give some ~3 mins for target's to become healthy.
        public_ip = "107.20.96.243,54.225.16.22" -> Use these IP's to access the EC2 instance with the key_pair downloaded.