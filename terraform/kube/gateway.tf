# The internal Gateway, its Let's Encrypt wildcard certificate and the
# HTTP-to-HTTPS redirect
resource "helm_release" "gateway" {
  name      = "gateway"
  chart     = "./charts/gateway"
  namespace = module.gateway_namespace.name
  set = [
    {
      # helm_release doesn't notice template edits in a local chart unless a
      # value changes, so pass a hash of every file in the chart.
      name  = "checksum"
      value = sha1(join("", [for f in sort(fileset("${path.module}/charts/gateway", "**")) : filesha1("${path.module}/charts/gateway/${f}")]))
    },
  ]
  depends_on = [helm_release.pki-acme, helm_release.cluster-base]
}
