# Secrets that only machines read. Terraform generates them and writes them
# with data_json_wo, so neither the values nor their hashes reach the state.
# When you raise data_json_wo_version, Terraform writes a new value. Gitea
# and Valkey read these when they start, so restart them afterwards. Gitea
# also keeps its own copy of the admin password. Change that copy with
# `gitea admin user change-password`.
#
# special = false keeps the passwords safe inside a rediss:// URL.

ephemeral "random_password" "gitea_admin" {
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "gitea_admin" {
  mount = vault_mount.kv.path
  name  = "apps/gitea/admin"
  data_json_wo = jsonencode({
    username = var.gitea_admin_username
    password = ephemeral.random_password.gitea_admin.result
  })
  data_json_wo_version = 1
}

ephemeral "random_password" "valkey_default" {
  length  = 32
  special = false
}

ephemeral "random_password" "valkey_gitea" {
  length  = 32
  special = false
}

# The Valkey metrics exporter logs in as default, and Gitea logs in as gitea.
resource "vault_kv_secret_v2" "gitea_valkey" {
  mount = vault_mount.kv.path
  name  = "apps/gitea/valkey"
  data_json_wo = jsonencode({
    default = ephemeral.random_password.valkey_default.result
    gitea   = ephemeral.random_password.valkey_gitea.result
  })
  data_json_wo_version = 1
}

ephemeral "random_password" "gitea_metrics" {
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "gitea_metrics" {
  mount = vault_mount.kv.path
  name  = "apps/gitea/metrics"
  data_json_wo = jsonencode({
    token = ephemeral.random_password.gitea_metrics.result
  })
  data_json_wo_version = 1
}
