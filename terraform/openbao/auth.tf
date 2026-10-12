# Pods log in with a ServiceAccount token. OpenBao checks each token with the
# TokenReview API. It calls the API as its own ServiceAccount, which the Helm
# chart binds to system:auth-delegator.
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc:443"
}

# People log in with a username and password. Terraform creates the mount but
# not the users, because userpass requires a password at creation.
resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = "userpass"
}
