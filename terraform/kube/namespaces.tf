# Platform namespaces. The API server calls webhooks in cert-manager and
# external-secrets, and a wrong network policy there breaks admission for the
# whole cluster. Apart from openbao, these namespaces get network policies
# after Hubble shows their real traffic.
module "cert_manager_namespace" {
  source            = "./modules/product-namespace"
  name              = "cert-manager"
  pod_security      = "restricted"
  trust_internal_ca = true # SecretStore caProvider reads the internal CA bundle
  openbao_reader    = true # SecretStore for the Porkbun API key
  default_deny      = false
}

# Holds the internal Gateway. The Gateway's Envoy runs in the cilium-envoy
# DaemonSet in kube-system, so this namespace has no pods.
module "gateway_namespace" {
  source       = "./modules/product-namespace"
  name         = "gateway"
  pod_security = "restricted"
  default_deny = false
}

module "openbao_namespace" {
  source            = "./modules/product-namespace"
  name              = "openbao"
  pod_security      = "restricted"
  gateway           = true # HTTPRoute for bao.internal.touchgrass.software
  trust_internal_ca = true # BackendTLSPolicy validates OpenBao against the internal CA
}

module "external_secrets_namespace" {
  source       = "./modules/product-namespace"
  name         = "external-secrets"
  pod_security = "restricted"
  default_deny = false
}

# Holds the CloudNativePG operator
module "pg_operator_namespace" {
  source       = "./modules/product-namespace"
  name         = "pg-operator"
  pod_security = "restricted"
  default_deny = false
}

# Products. Each product namespace holds the app, its PostgreSQL cluster and
# its Valkey, so their Secrets never cross namespaces. Move pod_security to
# restricted once `kubectl label --dry-run=server` shows no warnings.
module "gitea_namespace" {
  source            = "./modules/product-namespace"
  name              = "gitea"
  gateway           = true
  trust_internal_ca = true
  openbao_reader    = true
  # Two PostgreSQL instances, two PgBouncer pods, Valkey and Gitea are sized
  # to request about 1.7 CPU and 7.4 GiB. The job that copies data into a new
  # PostgreSQL instance briefly requests as much as one more instance.
  quota = {
    "requests.cpu"           = "4"
    "requests.memory"        = "12Gi"
    "persistentvolumeclaims" = "10"
    "requests.storage"       = "200Gi"
  }
}
