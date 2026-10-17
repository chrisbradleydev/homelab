# External Secrets copies secrets from OpenBao into Kubernetes Secrets. It
# talks to OpenBao through the stable vault provider, because the openbao
# provider is still alpha. The External Secrets project tests v2.13 on
# Kubernetes up to 1.36, and the cluster runs 1.37. Upgrade when a release
# tested on 1.37 ships.
resource "helm_release" "external-secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = module.external_secrets_namespace.name
  version    = "2.13.0"
  values = [
    yamlencode({
      installCRDs = true
      crds = {
        # Without this annotation, helm uninstall deletes the CRDs. Kubernetes
        # then deletes every ExternalSecret and every Secret they own.
        annotations = { "helm.sh/resource-policy" = "keep" }
      }
      priorityClassName = "platform-critical"
      resources = {
        requests = { cpu = "20m", memory = "128Mi" }
        limits   = { memory = "128Mi" }
      }
      webhook = {
        priorityClassName = "platform-critical"
        resources = {
          requests = { cpu = "10m", memory = "64Mi" }
          limits   = { memory = "64Mi" }
        }
      }
      certController = {
        priorityClassName = "platform-critical"
        resources = {
          requests = { cpu = "10m", memory = "64Mi" }
          limits   = { memory = "64Mi" }
        }
      }
    })
  ]
}

# The cert-manager namespace's SecretStore and the ExternalSecret for the
# Porkbun API key
resource "helm_release" "platform-secrets" {
  name      = "platform-secrets"
  chart     = "./charts/platform-secrets"
  namespace = module.cert_manager_namespace.name
  set = [
    {
      # helm_release doesn't notice template edits in a local chart unless a
      # value changes, so pass a hash of every file in the chart.
      name  = "checksum"
      value = sha1(join("", [for f in sort(fileset("${path.module}/charts/platform-secrets", "**")) : filesha1("${path.module}/charts/platform-secrets/${f}")]))
    },
  ]
  depends_on = [helm_release.external-secrets, helm_release.openbao, helm_release.trust-manager]
}
