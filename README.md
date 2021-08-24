

***
    Note: This Terraform code will make use of existing VPC in the region (default VPC) and it's subnets. This code will not create new VPC/Subnets/Routetables/NACL's.
***

If you want to override the backed S3 configuration, please run "terraform init" with below options.

terraform init \
-backend-config="bucket=${Your bucket name}" \
-backend-config="key=${Your key name}" \
-backend-config="region=${Your region}" 