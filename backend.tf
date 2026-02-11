# S3 remote state backend. Fill in values from bootstrap outputs:
#   terraform output -json backend_config

terraform {
  backend "s3" {
    bucket         = "aws-demo-demo-tfstate-381492075850"
    key            = "aws-demo/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "aws-demo-demo-tflock"
    encrypt        = true
  }
}
