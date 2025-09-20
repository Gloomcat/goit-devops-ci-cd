module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "devops-ci-cd-s3-bucket"
  table_name  = "terraform-locks"
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
  vpc_name           = "devops-ci-cd-vpc"
  create_nat_gateway = false

}

module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "devops-ci-cd-ecr"
  scan_on_push = true
}

module "eks" {
  source          = "./modules/eks"
  cluster_name    = "devops-ci-cd-cluster-demo"
  subnet_ids      = module.vpc.public_subnet_ids
  instance_type   = "t3.medium"
  node_group_name = "general"

  desired_size = 1
  max_size     = 2
  min_size     = 1
}

module "argo_cd" {
  source           = "./modules/argo_cd"
  cluster_name     = module.eks.eks_cluster_name
  kube_host        = module.eks.eks_cluster_endpoint
  kube_ca          = module.eks.eks_cluster_ca
  cluster_region   = "eu-north-1"
  namespace        = "argocd"
  image_repository = module.ecr.repository_url

  # Wire Django DB settings into the Argo CD Application values
  django_db_engine   = "django.db.backends.postgresql"
  django_db_host     = module.rds.host
  django_db_port     = tostring(module.rds.port)
  django_db_name     = module.rds.db_name
  django_db_user     = module.rds.username
  django_db_password = "admin123AWS23"
}


module "jenkins" {
  source               = "./modules/jenkins"
  cluster_name         = module.eks.eks_cluster_name
  kube_host            = module.eks.eks_cluster_endpoint
  kube_ca              = module.eks.eks_cluster_ca
  cluster_region       = "eu-north-1"
  namespace            = "jenkins"

  # IRSA for Jenkins to access ECR
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  ecr_repository_arn   = module.ecr.repository_arn
  service_account_name = "jenkins-sa"
}

module "rds" {
  source = "./modules/rds"

  name                       = "django-app-db"
  use_aurora                 = false
  aurora_instance_count      = 2

  # --- Aurora-only ---
  engine_cluster             = "aurora-postgresql"
  engine_version_cluster     = "15.3"
  parameter_group_family_aurora = "aurora-postgresql15"

  # --- RDS-only ---
  engine                     = "postgres"
  engine_version             = "17.2"
  parameter_group_family_rds = "postgres17"

  # Common
  instance_class             = "db.t3.medium"
  allocated_storage          = 20
  db_name                    = "app"
  username                   = "postgres"
  password                   = "admin123AWS23"
  subnet_private_ids         = module.vpc.private_subnet_ids
  subnet_public_ids          = module.vpc.public_subnet_ids
  publicly_accessible        = true
  vpc_id                     = module.vpc.vpc_id
  multi_az                   = true
  backup_retention_period    = 7
  parameters = {
    max_connections              = "200"
    log_min_duration_statement   = "500"
  }

  tags = {
    Environment = "dev"
    Project     = "myapp"
  }
}
