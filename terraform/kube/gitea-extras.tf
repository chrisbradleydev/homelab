# The gitea namespace's SecretStore, the ExternalSecrets, the Valkey
# certificate and the network policies for Gitea and Valkey
resource "helm_release" "gitea-extras" {
  name      = "gitea-extras"
  chart     = "./charts/gitea-extras"
  namespace = module.gitea_namespace.name
  set = [
    {
      # helm_release doesn't notice template edits in a local chart unless a
      # value changes, so pass a hash of every file in the chart.
      name  = "checksum"
      value = sha1(join("", [for f in sort(fileset("${path.module}/charts/gitea-extras", "**")) : filesha1("${path.module}/charts/gitea-extras/${f}")]))
    },
  ]
  depends_on = [helm_release.external-secrets, helm_release.openbao, helm_release.pki-internal]
}
