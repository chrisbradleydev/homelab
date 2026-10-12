variable "products" {
  description = "Product namespaces. Each gets a policy and a Kubernetes auth role that read kv/apps/<namespace>/*."
  type        = set(string)
  default     = ["gitea"]
}

variable "gitea_admin_username" {
  description = "Gitea's first admin user. Gitea rejects the name admin."
  type        = string
  default     = "gitea-admin"
}
