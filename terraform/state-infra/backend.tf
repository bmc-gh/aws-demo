terraform {
  backend "s3" {
    bucket         = "terraform-state-978794836516-861492"
    key            = "aws-platform-demo/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
