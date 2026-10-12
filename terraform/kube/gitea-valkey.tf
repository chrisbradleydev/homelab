# Valkey holds Gitea's cache, sessions, queues and locks. It runs as one
# server with an append-only file. The chart has no released Sentinel
# support, and the Valkey operator's README says it isn't ready for
# production. Terraform installs gitea-extras first, because the server
# needs the password Secret and the certificate from it to start.
resource "helm_release" "gitea-valkey" {
  name       = "gitea-valkey"
  repository = "https://valkey.io/valkey-helm/"
  chart      = "valkey"
  namespace  = module.gitea_namespace.name
  version    = "0.12.0"
  values     = [file("gitea-valkey.yaml")]
  depends_on = [helm_release.gitea-extras, helm_release.cluster-base]
}
