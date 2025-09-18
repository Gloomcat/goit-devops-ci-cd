terraform {
  backend "s3" {
    bucket         = "devops-ci-cd-s3-bucket"
    key            = "devops-ci-cd/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}