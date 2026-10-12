# Tier-0 secrets are the ones OpenBao needs before it can start. Ephemeral
# resources decrypt them during plan and apply without writing them to the
# state. Other secrets belong in OpenBao.
ephemeral "sops_file" "ceph" {
  source_file = "./secrets/ceph.enc.yaml"
}

# The 32-byte key that OpenBao's static seal uses. Losing it makes OpenBao's
# raft data unreadable, so keep a second copy outside this repository.
ephemeral "sops_file" "openbao" {
  source_file = "./secrets/openbao.enc.yaml"
}
