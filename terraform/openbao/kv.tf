resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv"
  options     = { version = "2" }
  description = "Platform and product secrets, read by External Secrets"
}
