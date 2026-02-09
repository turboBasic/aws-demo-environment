# S3 remote state backend. Fill in values from bootstrap outputs:
#   terraform output -json backend_config
#
# terraform {
#   backend "s3" {
#     bucket         = "<bootstrap: state_bucket_name>"
#     key            = "aws-demo/terraform.tfstate"
#     region         = "eu-central-1"
#     dynamodb_table = "<bootstrap: dynamodb_table_name>"
#     encrypt        = true
#   }
# }
