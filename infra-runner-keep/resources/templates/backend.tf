terraform {
  backend "s3" {
    bucket         = "ww-management-cluster-terraform-state"
    key            = "leaf-clusters/$CLUSTER_NAME/$TEMPLATE_NAME/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "nab-terraform-remote-state-lock-table"
  }
}