# Full access, for the people who run Terraform and administer OpenBao. It
# includes update on auth/token/create, which the provider needs for its
# child token.
resource "vault_policy" "admin" {
  name   = "admin"
  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
    }
  EOT
}

# For the snapshot CronJob in terraform/kube/charts/openbao-extras
resource "vault_policy" "snapshot" {
  name   = "snapshot"
  policy = <<-EOT
    path "sys/storage/raft/snapshot" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "snapshot" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "snapshot"
  bound_service_account_names      = ["openbao-snapshot"]
  bound_service_account_namespaces = ["openbao"]
  audience                         = "openbao"
  token_policies                   = [vault_policy.snapshot.name]
  token_ttl                        = 900
}
