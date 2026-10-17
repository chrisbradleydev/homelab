# The cert-manager project tests v1.21 on Kubernetes 1.33 to 1.36, and the
# cluster runs 1.37. cert-manager uses only stable Kubernetes APIs. Move to
# v1.22 when it ships.
resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = "oci://quay.io/jetstack/charts"
  chart      = "cert-manager"
  namespace  = module.cert_manager_namespace.name
  version    = "v1.21.2"
  values     = [file("cert-manager.yaml")]
}

# cert-manager has no built-in Porkbun solver. This community webhook is the
# only one still maintained. The image digest below passed this check:
#   cosign verify ghcr.io/octabits-io/cert-manager-webhook-porkbun:2.0.8 \
#     --certificate-identity-regexp '^https://github.com/octabits-io/cert-manager-webhook-porkbun/' \
#     --certificate-oidc-issuer https://token.actions.githubusercontent.com
# The webhook reads the Porkbun API key from the porkbun-api-credentials
# Secret, which doesn't exist until External Secrets copies it from OpenBao.
resource "helm_release" "cert-manager-webhook-porkbun" {
  name       = "cert-manager-webhook-porkbun"
  repository = "oci://ghcr.io/octabits-io/charts"
  chart      = "cert-manager-webhook-porkbun"
  namespace  = module.cert_manager_namespace.name
  version    = "2.0.8"
  values = [
    yamlencode({
      # ClusterIssuers name this group in their dns01.webhook solver
      groupName = "acme.touchgrass.software"
      image = {
        digest = "sha256:c0c3231e459b08d5fa87e66830594295a55214ffa63303ff40536e0894b4ac36"
      }
      rbac = {
        secretAccess = {
          secretNames = ["porkbun-api-credentials"]
        }
      }
      priorityClassName = "platform-critical"
      resources = {
        requests = { cpu = "10m", memory = "64Mi" }
        limits   = { memory = "64Mi" }
      }
    })
  ]
  # The chart issues its own serving certificate through cert-manager
  depends_on = [helm_release.cert-manager]
}

# Copies the internal root CA into a ConfigMap in every namespace labelled
# trust.touchgrass.software/internal-ca. The Bundle in charts/pki-internal
# tells it what to copy.
resource "helm_release" "trust-manager" {
  name       = "trust-manager"
  repository = "oci://quay.io/jetstack/charts"
  chart      = "trust-manager"
  namespace  = module.cert_manager_namespace.name
  version    = "v0.25.0"
  values = [
    yamlencode({
      priorityClassName = "platform-critical"
      resources = {
        requests = { cpu = "10m", memory = "128Mi" }
        limits   = { memory = "128Mi" }
      }
    })
  ]
  # trust-manager's webhook gets its serving certificate from cert-manager
  depends_on = [helm_release.cert-manager]
}

resource "helm_release" "pki-internal" {
  name      = "pki-internal"
  chart     = "./charts/pki-internal"
  namespace = module.cert_manager_namespace.name
  set = [
    {
      # helm_release doesn't notice template edits in a local chart unless a
      # value changes, so pass a hash of every file in the chart.
      name  = "checksum"
      value = sha1(join("", [for f in sort(fileset("${path.module}/charts/pki-internal", "**")) : filesha1("${path.module}/charts/pki-internal/${f}")]))
    },
  ]
  depends_on = [helm_release.cert-manager, helm_release.trust-manager]
}

# The Let's Encrypt ClusterIssuers. They solve DNS-01 through the Porkbun
# webhook, with the API key in porkbun-api-credentials.
resource "helm_release" "pki-acme" {
  name      = "pki-acme"
  chart     = "./charts/pki-acme"
  namespace = module.cert_manager_namespace.name
  set = [
    {
      # helm_release doesn't notice template edits in a local chart unless a
      # value changes, so pass a hash of every file in the chart.
      name  = "checksum"
      value = sha1(join("", [for f in sort(fileset("${path.module}/charts/pki-acme", "**")) : filesha1("${path.module}/charts/pki-acme/${f}")]))
    },
  ]
  depends_on = [helm_release.cert-manager-webhook-porkbun, helm_release.platform-secrets]
}
