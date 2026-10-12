# Each role binds one namespace's openbao-reader ServiceAccount to a policy
# that reads only that namespace's path, so one namespace can't read
# another's secrets. The ServiceAccounts come from the product-namespace
# module in terraform/kube.
locals {
  readers = merge(
    { for p in var.products : p => "kv/data/apps/${p}" },
    { "cert-manager" = "kv/data/platform/cert-manager" },
  )
}

resource "vault_policy" "reader" {
  for_each = local.readers
  name     = "ns-${each.key}"
  policy   = <<-EOT
    path "${each.value}/*" {
      capabilities = ["read"]
    }
    path "${replace(each.value, "kv/data/", "kv/metadata/")}/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "reader" {
  for_each                         = local.readers
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "ns-${each.key}"
  bound_service_account_names      = ["openbao-reader"]
  bound_service_account_namespaces = [each.key]
  audience                         = "openbao"
  token_policies                   = [vault_policy.reader[each.key].name]
  token_ttl                        = 900
}
