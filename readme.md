# Terraform EC2 Ubuntu example

This folder contains Terraform code to provision an Ubuntu EC2 instance in the default VPC with a generated SSH key saved to the current folder.

Files:
- `provider.tf` - provider and required providers
- `variables.tf` - variables
- `main.tf` - resources: key, security group, instance
- `userdata.tpl` - user-data for installing Docker, Docker Compose, and Terraform
- `terraform.tfvars` - example variable values
- `outputs.tf` - outputs

Components Installed
- Ubuntu EC2 on AWS
- install all the dependency software
  - docker using cloud-init
  - other software using the provisioners
  - after theproper wait period
  - added the SSH key on jenkins
  - added this node to the jenkins as node

Run:

1. Ensure AWS credentials are available (env vars or shared credentials file).
2. From this folder run:

```powershell
terraform init
terraform plan -out plan.tfplan
terraform apply "plan.tfplan"
```

The generated private key will be written to `./${var.key_name_prefix}.pem` (by default `./devsecops_key.pem`). Set strict permissions before SSH: `chmod 600 ./devsecops_key.pem`.

SSH example:

```powershell
ssh -i .\devsecops_key.pem ubuntu@<public_ip>
```
