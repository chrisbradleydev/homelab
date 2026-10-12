terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    # Namespaces, ServiceAccounts and tier-0 Secrets. Custom resources go in
    # local Helm charts under charts/, because helm_release doesn't need the
    # CRDs to exist at plan time.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.3.0"
    }
    # 1.3.0 added ephemeral "sops_file", which keeps decrypted values out of
    # the state
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "home"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "home"
}
