locals {
  # The Ceph cluster fsid. It tells ceph-csi which cluster to use and isn't a
  # credential.
  ceph_cluster_id = "dff33313-6a13-48cb-8229-668ab5246e6c"
}

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
        cluster-id = local.ceph_cluster_id,
      }
    )
  ]
}

# ceph-csi reads the Ceph client credentials from this Secret. The chart
# doesn't create it. Chart values can't take write-only input, so Helm and
# Terraform would both store the key. To rotate the key, update
# secrets/ceph.enc.yaml. Then raise data_wo_revision.
resource "kubernetes_secret_v1" "csi-cephfs-secret" {
  metadata {
    name      = "csi-cephfs-secret"
    namespace = "ceph-csi-rbd"
  }
  data_wo = {
    userID  = ephemeral.sops_file.ceph.data["userId"]
    userKey = ephemeral.sops_file.ceph.data["userKey"]
  }
  data_wo_revision = 1
  # The chart release creates the ceph-csi-rbd namespace that this Secret
  # lives in
  depends_on = [helm_release.ceph-csi-rbd]
}
