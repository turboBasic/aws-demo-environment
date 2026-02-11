# S3 remote state backend. Fill in values from bootstrap outputs:
# cd backup && terraform output -json backend_config

terraform {
  backend "s3" {
    bucket         = "ade-dev-tfstate-381492075850"
    key            = "ade/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "ade-dev-tflock"
    encrypt        = true
  }
}
