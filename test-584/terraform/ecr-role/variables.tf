variable "repo_name" {
  type        = string
  description = "ECR Repo name"
}

variable "tags" {
  type        = map(string)
  description = "resource specific tags"
  default     = {
    customer   = "weaveworks-cx"
    projectGid = "99999"
    creator    = "paul-carlton@weave.works"
  }
}

variable "cluster_name" {
  type        = string
  description = "name of cluster to associate permissions with"
}

variable "awsAccountId" {
  type        = string
  description = "AWS account id"
  default     = ""
}

variable "awsRegion" {
  type        = string
  description = "AWS region"
  default     = ""
}

variable "service_account" {
  type        = string
  description = "serviceaccount name"
  default     = ""
}

variable "sa_namespace" {
  type        = string
  description = "serviceaccount namespace"
  default     = ""
}

variable "cluster_oidc_provider_arn" {
  type        = string
  description = " Cluster OIDC provider arn"
}

variable "cluster_oidc_provider_url" {
  type        = string
  description = " Cluster OIDC provider url"
}

variable "role_name" {
  type        = string
  description = "name of role"
}

variable "ecr_names" {
  type    = list(string)
  default = []
  description = "list of ecr repostories"
}
