# OpenBao's static seal reads this key when a server starts, so pods unseal
# on their own after a restart or a node drain. binary_data_wo takes base64
# and writes the raw 32 bytes, which OpenBao reads byte for byte. To rotate
# the key, first add the old key as previous_key in the seal "static" stanza
# in openbao.yaml. Then update secrets/openbao.enc.yaml and raise
# binary_data_wo_revision.
resource "kubernetes_secret_v1" "openbao-unseal" {
  metadata {
    name      = "openbao-unseal"
    namespace = module.openbao_namespace.name
  }
  binary_data_wo = {
    "unseal.key" = ephemeral.sops_file.openbao.data["unsealKey"]
  }
  binary_data_wo_revision = 1

  # Without this key, nobody can read OpenBao's raft data
  lifecycle {
    prevent_destroy = true
  }
}

# The TLS certificate, the network policies and the snapshot job. The servers
# mount the certificate, and the policies have to allow retry_join before the
# servers start.
resource "helm_release" "openbao-extras" {
  name      = "openbao-extras"
  chart     = "./charts/openbao-extras"
  namespace = module.openbao_namespace.name
  set = [
    {
      # helm_release doesn't notice template edits in a local chart unless a
      # value changes, so pass a hash of every file in the chart.
      name  = "checksum"
      value = sha1(join("", [for f in sort(fileset("${path.module}/charts/openbao-extras", "**")) : filesha1("${path.module}/charts/openbao-extras/${f}")]))
    },
  ]
  depends_on = [helm_release.pki-internal]
}

# The StatefulSet uses the OnDelete update strategy, so a chart upgrade
# changes no running pod. To roll the pods:
#   1. Delete the standby pods one at a time, and wait for each to be Ready.
#   2. Run `bao operator step-down` on the active pod.
#   3. Delete the old active pod.
# A new cluster's servers stay NotReady until `bao operator init` runs once,
# so Terraform doesn't wait for them.
resource "helm_release" "openbao" {
  name       = "openbao"
  repository = "https://openbao.github.io/openbao-helm"
  chart      = "openbao"
  namespace  = module.openbao_namespace.name
  version    = "0.30.4"
  values     = [file("openbao.yaml")]
  wait       = false
  depends_on = [helm_release.openbao-extras, kubernetes_secret_v1.openbao-unseal]
}
