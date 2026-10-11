# 3.17.1 is the last chart version that runs on these nodes. From 3.18.0 on,
# the cephcsi image uses Rocky Linux 10, which needs x86-64-v3 CPU features
# such as AVX2. The CPUs in pve1 and pve2 lack them, so cephcsi exits with
# "Fatal glibc error: CPU does not support x86-64-v3".
resource "helm_release" "ceph-csi-rbd" {
  name             = "ceph-csi-rbd"
  repository       = "https://ceph.github.io/csi-charts"
  chart            = "ceph-csi-rbd"
  namespace        = "ceph-csi-rbd"
  version          = "3.17.1"
  create_namespace = true
  depends_on       = [helm_release.snapshot-controller]
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
