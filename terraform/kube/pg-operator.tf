# CloudNativePG runs the PostgreSQL clusters. The Percona operator was the
# first choice, but Percona builds its operator images on UBI10 since 2.9.
# UBI10's glibc needs x86-64-v3, and the Proxmox hosts support only
# x86-64-v2. The CloudNativePG operator is a static binary on distroless, and
# its PostgreSQL and PgBouncer images are Debian. The image digest below passed
# this check:
#   cosign verify ghcr.io/cloudnative-pg/cloudnative-pg:1.30.1 \
#     --certificate-identity-regexp '^https://github.com/cloudnative-pg/cloudnative-pg/' \
#     --certificate-oidc-issuer https://token.actions.githubusercontent.com
# The chart installs the CRDs with helm.sh/resource-policy: keep, so
# helm uninstall leaves every Cluster and its data in place.
resource "helm_release" "pg-operator" {
  name       = "pg-operator"
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  namespace  = module.pg_operator_namespace.name
  version    = "0.29.1"
  values = [
    yamlencode({
      # Use the names from the upstream manifests and docs
      fullnameOverride = "cnpg-controller-manager"
      image = {
        # The operator also starts every PostgreSQL pod's init container from
        # this image, so this digest pins the init container too
        tag = "1.30.1@sha256:923c267ec29636db3bee20f993d0ec4973fa22998e1adad37da79e4d32b5bc07"
      }
      priorityClassName = "platform-critical"
      resources = {
        requests = { cpu = "50m", memory = "256Mi" }
        limits   = { memory = "256Mi" }
      }
    })
  ]
}
