data "sops_file" "ceph" {
  source_file = "./secrets/ceph.enc.yaml"
}
