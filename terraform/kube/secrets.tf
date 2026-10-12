# Tier-0 secrets are the ones OpenBao needs before it can start. Ephemeral
# resources decrypt them during plan and apply without writing them to the
# state. Other secrets belong in OpenBao.
ephemeral "sops_file" "ceph" {
  source_file = "./secrets/ceph.enc.yaml"
}
