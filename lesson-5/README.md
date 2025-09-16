# Lesson 5 — Terraform

## Install Terraform

Official guide: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

(Recommended: install and configure AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Setup S3 backend

### Notes
- Commit `.terraform.lock.hcl` to the repository for reproducible builds.
- Ensure AWS credentials and the region (`eu-north-1`) are configured properly.
- S3 bucket names must be globally unique. If the default `devops-ci-cd-s3-bucket` conflicts, change it consistently in `lesson-5/main.tf` and `lesson-5/backend.tf`.

1) Temporarily disable the S3 backend (rename `lesson-5/backend.tf` to `backend.tf.disabled`, or comment out the `backend "s3"` block)

2) Initialize Terraform without backend (local state first)
```bash
cd lesson-5
terraform init
```

3) Create backend resources (S3 bucket + DynamoDB table) via module
```bash
terraform apply -target="module.s3_backend"
```

4) Restore or create lesson-5/backend.tf with the S3 backend configuration:
```hcl
terraform {
  backend "s3" {
    bucket         = "devops-ci-cd-s3-bucket"
    key            = "lesson-5/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

5) Reconfigure to use the S3 backend (migrates local state to S3)
```bash
terraform init
```

## Validate, plan and apply the full infrastructure

```bash
terraform validate
terraform plan
terraform apply
```

## Modules

- s3-backend (lesson-5/modules/s3-backend)
  - Purpose: provisions the remote state backend resources
    - S3 bucket for Terraform state (versioning enabled, BucketOwnerEnforced ownership, SSE-S3 encryption)
    - DynamoDB table for state locking (hash key: LockID, PAY_PER_REQUEST)
  - Inputs: bucket_name, table_name
  - Outputs: s3_bucket_url, dynamodb_table_name

- vpc (lesson-5/modules/vpc)
  - Purpose: creates networking baseline
    - VPC CIDR 10.0.0.0/16
    - 3 public and 3 private subnets across eu-north-1a/b/c
    - Internet Gateway, NAT Gateway (with EIP), route tables and associations
  - Outputs: vpc_id, public_subnet_ids, private_subnet_ids, internet_gateway_id, nat_gateway_id

- ecr (lesson-5/modules/ecr)
  - Purpose: creates ECR repository for container images
    - Repository name: lesson-5-ecr (scan_on_push enabled)
    - Repository policy restricted to current AWS account root for push/pull
  - Outputs: ecr_repository_url, ecr_repository_arn

## Full cleanup (destroy everything)

1) Disable the S3 backend (rename `lesson-5/backend.tf` to `backend.tf.disabled`, or comment out the `backend "s3"` block)

2) Remove S3 to local backend
    - Re-initialize and migrate state to local:
    ```bash
    terraform init -migrate-state
    ```
3) Destroy application infrastructure and the backend resources (bucket + lock table)
    ```bash
    terraform destroy
    ```
4) (Optional) Remove all terraform generated files if you do not want to persist state locally
    ```text
    .terraform, terraform.tfstate, terraform.tfstate.backup, etc.
    ```
