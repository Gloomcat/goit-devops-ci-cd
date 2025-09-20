# Project — Terraform + EKS + Helm + Jenkins + ArgoCD (Django app)

## Overview

This project provisions a minimal, demo‑friendly Kubernetes stack on AWS, deploys Jenkins via Helm, and uses Argo CD for GitOps (auto‑deploying the sample Django app from this repo).
- Terraform creates: VPC, ECR, EKS (managed node group), aws-ebs-csi-driver add‑on, Jenkins, and Argo CD.
- Jenkins builds/pushes images to ECR and bumps the chart image.tag in this repository.
- Argo CD (Service type LoadBalancer, namespace argocd) watches the dev branch and syncs the django-app chart to the cluster.
- The Django app chart lives in project/charts/django-app:
  - Service type LoadBalancer exposes an external AWS ELB URL, shows OK/FAIL based on DB connectivity on index.
  - ConfigMap injects non‑secret env (DJANGO_DEBUG, DJANGO_ALLOWED_HOSTS, DATABASE_ENGINE/HOST/PORT/NAME/USER)
  - DATABASE_PASSWORD is also passed via Helm values for now; could be switched to a Secret in production
  - PostgreSQL only (RDS PostgreSQL or Aurora PostgreSQL). Terraform wires DB settings from the RDS module → Argo CD Application → Helm chart → ConfigMap → Pod env
  - Currently configured to use the WRITER endpoint only; the reader endpoint is ignored
  - Deployment uses a zero‑surge update strategy (maxSurge: 0) to fit small clusters.


### Monitoring (Prometheus + Grafana) — usage
- Installed via Terraform Helm module (kube-prometheus-stack) in namespace `monitoring`
- Helm repository: https://prometheus-community.github.io/helm-charts, chart: `kube-prometheus-stack`
- Grafana access (default internal):
  - Get admin password:
    - `kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo`
  - Port-forward and open:
    - `kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80`
    - Visit http://localhost:3000 (user: `admin`)
- Prometheus UI (optional):
  - `kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090`
  - Visit http://localhost:9090
- To expose externally via LoadBalancer or Ingress, edit `project/modules/monitoring/values.yaml` (e.g., set `grafana.service.type: LoadBalancer`) and re-apply Terraform.

## How it works (end-to-end)
1) Provision infra with Terraform (VPC, ECR, EKS, aws-ebs-csi-driver add-on, Jenkins, and Argo CD). Backend: local by default; S3/DynamoDB is optional.
2) Configure kubectl and retrieve endpoints (Jenkins and Argo CD LoadBalancers).
3) Jenkins pipeline builds/pushes the Django image to ECR and updates image.tag in the Helm values in this repo.
4) Argo CD monitors the repo (branch `dev`) and automatically syncs the `django-app` chart to the cluster.
5) Access Jenkins and Argo CD via their LoadBalancer addresses; access the app via its Service EXTERNAL hostname.
6) Settings (database via RDS/Aurora):
   - `DJANGO_DEBUG` and `DJANGO_ALLOWED_HOSTS` are read from ConfigMap
   - `DATABASE_ENGINE/HOST/PORT/NAME/USER/PASSWORD` are forwarded from Terraform (RDS outputs) via Argo CD into the chart; the app uses the WRITER endpoint only
   - To switch engines, set `use_aurora = true` in module "rds" and apply. To force writer-only, set `django_db_host_reader = ""` in module "argo_cd" (current default)

## Node sizing
- Default node type: `t3.medium` (2 vCPU, 4 GiB RAM).
- For temporary extra capacity, increase `desired_size`; for single-node setups prefer a larger instance type rather than multiple micros.

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

## State backend (default: local; optional: S3)

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

Configure kubectl to connect to EKS
```bash
export REGION="eu-north-1"
export CLUSTER=$(terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"
kubectl get nodes
```

### Jenkins

1) Create required secrets for Jenkins

- Namespace (if not present):
```bash
kubectl create namespace jenkins || true
```

- Admin credentials (used by Jenkins Configuration as Code):
```bash
kubectl -n jenkins create secret generic jenkins-admin \
  --from-literal=ADMIN_USER=admin \
  --from-literal=ADMIN_PASSWORD='change-me' \
  --dry-run=client -o yaml | kubectl apply -f -
```

- GitHub credentials (for pipeline checkout/push):
```bash
kubectl -n jenkins create secret generic jenkins-github-ci \
  --from-literal=GITHUB_USER='your-github-username' \
  --from-literal=GITHUB_TOKEN='ghp_xxx' \
  --dry-run=client -o yaml | kubectl apply -f -
```

2) Get the Jenkins address:
```bash
terraform output -raw jenkins_hostname || terraform output -raw jenkins_ip
kubectl -n jenkins get svc jenkins -o wide
```

3) Log in:
- Username/password are the values you set in the `jenkins-admin` secret above.

4) Wait for the LoadBalancer and pods to be Ready:
```bash
kubectl -n jenkins get svc,deploy,pods -o wide
```

### Argo CD access and GitOps application deployment

1) Get Argo CD address (LoadBalancer):
```bash
kubectl -n argocd get svc argo-cd-argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# or IP if hostname is empty
kubectl -n argocd get svc argo-cd-argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

2) Get the initial admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

3) Log in to the Argo CD UI at the address above (username: `admin`).
- The Application `django-app` is created by Terraform and points to this repo on branch `dev`. It will auto-sync on changes (e.g., when Jenkins updates `image.tag`). You can also click Refresh/Sync in the UI.
4) Verify deployed resources (Argo CD deploys to namespace `default`):
```bash
kubectl -n default get deploy,svc,pods
```

### (Optional) Ensure HPA metrics
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

- rds (project/modules/rds)
  - Purpose: provisions PostgreSQL either as standard Amazon RDS or as an Aurora PostgreSQL cluster
  - Switch: `use_aurora` (false = RDS PostgreSQL instance; true = Aurora PostgreSQL cluster)
  - Important inputs (subset):
    - `engine`, `engine_version` (RDS) • `engine_cluster`, `engine_version_cluster`, `aurora_instance_count` (Aurora)
    - `db_name`, `username`, `password`, `instance_class`, `publicly_accessible`, `subnet_*`, `vpc_id`
  - Outputs consumed by Argo CD module:
    - `host` (writer endpoint)
    - `reader_host` (Aurora reader endpoint or null for RDS)
    - `port`, `db_name`, `username`
  - Notes: Aurora ignores `allocated_storage`; use `aurora_instance_count` for scaling. Ensure security groups/subnets allow the app to reach the DB port.

- eks (project/modules/eks)
  - Purpose: provisions an Amazon EKS cluster and a managed node group
    - Control plane with public endpoint access for this lesson
    - Worker nodes in public subnets (no NAT required)
    - Tagging aligned with other modules
  - Inputs: cluster_name, subnet_ids, node_group_name, instance_type, desired_size, min_size, max_size
  - Outputs: eks_cluster_name, eks_cluster_endpoint, eks_node_role_arn


- monitoring (project/modules/monitoring)
  - Purpose: installs the Kubernetes monitoring stack (Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics) via the `kube-prometheus-stack` Helm chart
  - Helm:
    - repository: `https://prometheus-community.github.io/helm-charts`
    - chart: `kube-prometheus-stack`
    - namespace: `monitoring`
  - Values: managed in `project/modules/monitoring/values.yaml`
    - To expose Grafana externally: set `grafana.service.type: LoadBalancer` (or configure Ingress) and re-apply Terraform
    - Similarly, you can expose Prometheus via `prometheus.service.type: LoadBalancer`
  - Usage:
    - Get Grafana admin password:
      - `kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo`
    - Port-forward Grafana locally: `kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80` → open http://localhost:3000 (user: `admin`)
    - Prometheus UI (optional): `kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090`

- jenkins (project/modules/jenkins)
  - Purpose: installs Jenkins via Helm (Service type LoadBalancer) in namespace jenkins
  - Values layering: module default values.yaml + optional values_overrides (local project/jenkins/values.local.yaml)
  - Service account: jenkins-sa with IRSA to access AWS as configured
  - Outputs: jenkins_hostname, jenkins_ip, jenkins_admin_password

- argo_cd (project/modules/argo_cd)
  - Purpose: installs Argo CD via Helm (Service type LoadBalancer) in namespace argocd, and registers the Git repository + Application (`django-app`) for GitOps
  - Values overlay: forwards image.repository/tag and `config.DATABASE_*` into the Application `helm.values` so the app receives DB settings from Terraform (writer endpoint only; reader is ignored for now)
  - Destination & sync: `server=https://kubernetes.default.svc`, `namespace=default`; automated sync with `selfHeal` and `prune`
  - Inputs (subset): `image_repository`, `image_tag` (optional), `django_db_engine`, `django_db_host`, `django_db_host_reader`, `django_db_port`, `django_db_name`, `django_db_user`, `django_db_password`
  - Repository access: public GitHub repos work without credentials; for private repos, provide credentials via Terraform values/CI secrets
  - Access: retrieve the Argo CD server address and initial admin password using the kubectl commands shown above


## Charts (Helm)

- django-app (project/charts/django-app)
  - Deployment: runs the Django container image from ECR, pulls env via ConfigMap (envFrom)
  - Service: type LoadBalancer (port 80 → container port 8000)
  - HPA: autoscaling from 1 to 3 replicas at >70% CPU utilization
  - ConfigMap: non‑secret environment variables (DJANGO_DEBUG, DJANGO_ALLOWED_HOSTS, DATABASE_ENGINE/HOST/PORT/NAME/USER); DATABASE_PASSWORD is passed via Helm values (could be a Secret in production)
  - values.yaml: controls image (repository, tag), service ports, autoscaling, and resources (requests/limits)
  - Note: The app is PostgreSQL-only; DB settings are provided by Terraform/Argo CD and the app uses the WRITER endpoint

## Destroy and cleanup

1) Empty ECR repository:
```bash
export ECR=$(terraform output -raw ecr_repository_url)
export REPO="${ECR#*/}"
IMAGES=$(aws ecr list-images --repository-name "$REPO" --query 'imageIds' --output json)
if [ "$IMAGES" != "[]" ]; then
  aws ecr batch-delete-image --repository-name "$REPO" --image-ids "$IMAGES"
fi
```

2) Migrate state locally and destroy all resources (including the remote backend module):
```bash
terraform init -migrate-state
terraform destroy -auto-approve
```

3) (Optional) Remove local Terraform artifacts if you don't want to keep state locally
```text
.terraform/, terraform.tfstate, terraform.tfstate.backup, etc.
```
