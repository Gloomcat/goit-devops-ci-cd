# Project — Terraform + EKS + Helm + Jenkins + ArgoCD (Django app)

## Overview

This project provisions a minimal, demo-friendly Kubernetes stack on AWS and deploys a Django web app.
- Terraform creates: VPC, ECR, and an EKS cluster with a single managed node group.
- You build and push a Docker image to ECR.
- A Helm chart deploys the app to EKS:
  - Service type LoadBalancer exposes an external AWS ELB URL
  - ConfigMap injects non-secret env (e.g., DJANGO_DEBUG, DJANGO_ALLOWED_HOSTS, USE_SQLITE)
  - Default DB is SQLite for simplicity; the index page returns “Database connection: OK/ERROR”.
  - Deployment uses a zero-surge update strategy (maxSurge: 0) to fit small clusters.

## How it works (end-to-end)
1) Provision infra with Terraform (S3/DynamoDB backend for state, VPC networking, ECR, EKS)
2) Build/push the Django image to ECR
3) Deploy via Helm (charts/django-app)
4) Access the app via the Service EXTERNAL hostname from `kubectl get svc`
5) Settings:
   - `DJANGO_DEBUG` and `DJANGO_ALLOWED_HOSTS` are read from the environment (ConfigMap)
   - `USE_SQLITE=true` avoids external DB setup (can switch to Postgres later)

## t3.micro usage and AWS Free Tier autoscaling limitations
- Node type: `t3.micro` (burstable 2 vCPU credits, ~1 GiB RAM) is eligible for Free Tier when used as EC2.
- Consequences for demos:
  - Very limited Pod capacity and CPU; a single node often can’t host extra surge Pods during rolling updates.
  - We set `maxSurge: 0` and recommend keeping replicas at `1` to avoid Pending Pods.
  - Horizontal Pod Autoscaler (HPA) can increase replica count, but replicas may fail to schedule on a single `t3.micro` without Cluster Autoscaler (which is outside Free Tier intent).
  - Without metrics-server, HPA CPU scaling won’t function; with metrics-server but no spare capacity, Pods can still remain Pending.

Recommended for Free Tier labs:
- Keep `autoscaling.enabled=false` or `maxReplicas: 1` in `values.yaml`
- Maintain zero-surge updates (already configured)
- If you need real scaling, temporarily switch the node group to a bigger type (e.g., `t3.small`) — note this incurs cost and leaves Free Tier.

## Install Terraform

Official guide: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

Verify:
```bash
terraform -version
```

## Install AWS CLI

Official guide: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

- Ensure AWS credentials and the region (`eu-north-1`) are configured properly.

Verify:
```bash
aws --version
aws sts get-caller-identity
```

## Install Docker

- Windows/macOS: https://docs.docker.com/desktop/install/
- Linux (Engine): https://docs.docker.com/engine/install/

Verify:
```bash
docker version
```

## Install kubectl

Official guide: https://kubernetes.io/docs/tasks/tools/

Verify:
```bash
kubectl version --client --short
```

## Install Helm

Official guide: https://helm.sh/docs/intro/install/

Verify:
```bash
helm version
```

## Setup S3 backend

1) Cd to the project directory:
```bash
cd project
```

2) Temporarily disable the S3 backend (rename `project/backend.tf` to `backend.tf.disabled`, or comment out the `backend "s3"` block)

3) Initialize Terraform without backend (local state first)
- Commit `.terraform.lock.hcl` to the repository for reproducible builds.
```bash
terraform init
```

4) Create backend resources (S3 bucket + DynamoDB table) via module
- S3 bucket names must be globally unique. If the default `devops-ci-cd-s3-bucket` conflicts, change it consistently in `project/main.tf` and `project/backend.tf`.
```bash
terraform apply -target="module.s3_backend"
```

5) Restore or create project/backend.tf with the S3 backend configuration:
```hcl
terraform {
  backend "s3" {
    bucket         = "devops-ci-cd-s3-bucket"
    key            = "devops-ci-cd/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

6) Reconfigure to use the S3 backend (migrates local state to S3)
```bash
terraform init
```

## Validate, plan and apply the full infrastructure

```bash
terraform validate
terraform plan
terraform apply
```

## Kubernetes access and application deployment

1) Configure kubectl to connect to EKS
```bash
export REGION="eu-north-1"
export CLUSTER=$(terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"
kubectl get nodes
```

2) Build and push the Docker image to ECR
```bash
docker build -t django-app:latest ../app
export ECR=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$(echo "$ECR" | cut -d'/' -f1)"
docker tag django-app:latest "$ECR:latest"
docker push "$ECR:latest"
```

3) Deploy the app with Helm (image repository provided via CLI)
```bash
helm upgrade --install django ./charts/django-app \
  -n django --create-namespace \
  --set image.repository="$ECR" \
  --set image.tag=latest
```

4) Verify
```bash
kubectl get deploy,svc,hpa -n django
kubectl get svc django-django-app -n django -o wide
kubectl get pods -n django -o wide
```
Wait for service status to become `Running` instead of `<pending>`. Open the EXTERNAL-IP/Hostname from the Service in your browser.

5) (Optional) Ensure HPA metrics
```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system
kubectl get hpa -n django
```

## Modules

- s3-backend (project/modules/s3-backend)
  - Purpose: provisions the remote state backend resources
    - S3 bucket for Terraform state (versioning enabled, BucketOwnerEnforced ownership, SSE-S3 encryption)
    - DynamoDB table for state locking (hash key: LockID, PAY_PER_REQUEST)
  - Inputs: bucket_name, table_name
  - Outputs: s3_bucket_url, dynamodb_table_name

- vpc (project/modules/vpc)
  - Purpose: creates networking baseline
    - VPC CIDR 10.0.0.0/16
    - 3 public and 3 private subnets across eu-north-1a/b/c
    - Internet Gateway, NAT Gateway (with EIP), route tables and associations
  - Outputs: vpc_id, public_subnet_ids, private_subnet_ids, internet_gateway_id, nat_gateway_id

- ecr (project/modules/ecr)
  - Purpose: creates ECR repository for container images
    - Repository name: devops-ci-cd-ecr (scan_on_push enabled)
    - Repository policy restricted to current AWS account root for push/pull
  - Outputs: ecr_repository_url, ecr_repository_arn


- eks (project/modules/eks)
  - Purpose: provisions an Amazon EKS cluster and a managed node group
    - Control plane with public endpoint access for this lesson
    - Worker nodes in public subnets (no NAT required)
    - Tagging aligned with other modules
  - Inputs: cluster_name, subnet_ids, node_group_name, instance_type, desired_size, min_size, max_size
  - Outputs: eks_cluster_name, eks_cluster_endpoint, eks_node_role_arn

## Charts (Helm)

- django-app (project/charts/django-app)
  - Deployment: runs the Django container image from ECR, pulls env via ConfigMap (envFrom)
  - Service: type LoadBalancer (port 80 → container port 8000)
  - HPA: autoscaling from 1 to 3 replicas at >70% CPU utilization
  - ConfigMap: non‑secret environment variables (e.g., DJANGO_DEBUG, DJANGO_ALLOWED_HOSTS, USE_SQLITE)
  - values.yaml: controls image (repository, tag), service ports, autoscaling, and resources (requests/limits)
  - Note: USE_SQLITE is set to "true" by default for this lesson so no external DB is required

## Destroy and cleanup

1) Uninstall the Helm chart (ignore errors if not installed):
```bash
helm uninstall django -n django || true
```

2) Empty ECR repository:
```bash
export ECR=$(terraform output -raw ecr_repository_url)
export REPO="${ECR#*/}"
IMAGES=$(aws ecr list-images --repository-name "$REPO" --query 'imageIds' --output json)
if [ "$IMAGES" != "[]" ]; then
  aws ecr batch-delete-image --repository-name "$REPO" --image-ids "$IMAGES"
fi
```

3) Migrate state locally and destroy all resources (including the remote backend module):
```bash
terraform init -migrate-state
terraform destroy -auto-approve
```

4) (Optional) Remove local Terraform artifacts if you don't want to keep state locally
```text
.terraform/, terraform.tfstate, terraform.tfstate.backup, etc.
```
