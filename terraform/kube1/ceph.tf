resource "helm_release" "ceph-csi-rbd" {
  name             = "ceph-csi-rbd"
  repository       = "https://ceph.github.io/csi-charts"
  chart            = "ceph-csi-rbd"
  namespace        = "ceph-csi-rbd"
  version          = "3.14.1"
  create_namespace = true
  values = [
    templatefile(
      "ceph.yaml",
      {
        cluster-id = data.sops_file.ceph.data["clusterId"],
        user-id    = data.sops_file.ceph.data["userId"],
        user-key   = data.sops_file.ceph.data["userKey"],
      }
    )
  ]
}
