terraform {
  required_providers {
    # No OpenBao provider exists. OpenBao forked Vault 1.14 and keeps its API.
    vault = {
      source  = "hashicorp/vault"
      version = "5.13.0"
    }
    # 3.7.0 added ephemeral "random_password", which never writes the value
    # to the state
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }
}

# VAULT_ADDR, VAULT_TOKEN and VAULT_CACERT come from the environment. The
# provider creates a child token for each run, so the caller's token needs
# update on auth/token/create.
provider "vault" {}
