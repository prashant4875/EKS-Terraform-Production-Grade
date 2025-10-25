terraform {
  backend "s3" {
    bucket         = "my-company-terraform-state-psb-dev"
    key            = "eks/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-dev"

    # Workspace configuration
    workspace_key_prefix = "workspaces"
  }
}