variable "name" {
  description = "Namespace name"
  type        = string
}

variable "pod_security" {
  description = "Pod Security Standard to enforce: baseline or restricted. Every namespace warns on restricted."
  type        = string
  default     = "baseline"

  validation {
    condition     = contains(["baseline", "restricted"], var.pod_security)
    error_message = "pod_security must be baseline or restricted."
  }
}

variable "gateway" {
  description = "Let HTTPRoutes in this namespace attach to the internal Gateway"
  type        = bool
  default     = false
}

variable "trust_internal_ca" {
  description = "Have trust-manager copy the internal CA bundle into this namespace"
  type        = bool
  default     = false
}

variable "openbao_reader" {
  description = "Create the openbao-reader ServiceAccount that this namespace's SecretStore logs in with"
  type        = bool
  default     = false
}

variable "default_deny" {
  description = "Deny all ingress to pods until other CiliumNetworkPolicies allow it"
  type        = bool
  default     = true
}

variable "limit_range" {
  description = "Give containers without requests a default of 50m CPU and 64Mi memory, and a 256Mi memory limit"
  type        = bool
  default     = true
}

variable "quota" {
  description = "ResourceQuota hard limits, for example { \"requests.cpu\" = \"4\" }. Empty means no quota."
  type        = map(string)
  default     = {}
}
