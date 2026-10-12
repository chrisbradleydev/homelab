terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# Terraform creates every platform and product namespace with this module, so
# each one gets the same Pod Security labels, defaults and network policy.
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.name
    labels = merge(
      {
        "pod-security.kubernetes.io/enforce"         = var.pod_security
        "pod-security.kubernetes.io/enforce-version" = "latest"
        "pod-security.kubernetes.io/warn"            = "restricted"
        "pod-security.kubernetes.io/warn-version"    = "latest"
      },
      var.gateway ? { "gateway.touchgrass.software/internal" = "true" } : {},
      var.trust_internal_ca ? { "trust.touchgrass.software/internal-ca" = "true" } : {},
    )
  }

  # Deleting a namespace deletes every PVC, Secret and database in it
  lifecycle {
    prevent_destroy = true
  }
}

resource "kubernetes_service_account_v1" "openbao_reader" {
  count = var.openbao_reader ? 1 : 0

  metadata {
    name      = "openbao-reader"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  # External Secrets requests its own short-lived tokens for this account
  automount_service_account_token = false
}

# Operator Jobs and sidecars often set no requests. Without defaults they run
# as BestEffort, and the kubelet evicts them first.
resource "kubernetes_limit_range_v1" "defaults" {
  count = var.limit_range ? 1 : 0

  metadata {
    name      = "container-defaults"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
      default = {
        memory = "256Mi"
      }
    }
  }
}

resource "kubernetes_resource_quota_v1" "this" {
  count = length(var.quota) > 0 ? 1 : 0

  metadata {
    name      = "namespace-quota"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    hard = var.quota
  }
}

resource "helm_release" "default_deny" {
  count = var.default_deny ? 1 : 0

  name      = "default-deny"
  chart     = "${path.module}/../../charts/namespace-default-deny"
  namespace = kubernetes_namespace_v1.this.metadata[0].name
  set = [
    {
      # helm_release doesn't notice template edits in a local chart unless a
      # value changes, so pass a hash of every file in the chart.
      name  = "checksum"
      value = sha1(join("", [for f in sort(fileset("${path.module}/../../charts/namespace-default-deny", "**")) : filesha1("${path.module}/../../charts/namespace-default-deny/${f}")]))
    },
  ]
}
