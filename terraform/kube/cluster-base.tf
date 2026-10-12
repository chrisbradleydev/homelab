resource "helm_release" "cluster-base" {
  name      = "cluster-base"
  chart     = "./charts/cluster-base"
  namespace = "kube-system"
  set = [
    {
      name  = "cephClusterID"
      value = local.ceph_cluster_id
    },
    {
      # helm_release doesn't notice template edits in a local chart unless a
      # value changes, so pass a hash of every file in the chart.
      name  = "checksum"
      value = sha1(join("", [for f in sort(fileset("${path.module}/charts/cluster-base", "**")) : filesha1("${path.module}/charts/cluster-base/${f}")]))
    },
  ]
  # The StorageClass refers to the Secret that ceph.tf manages
  depends_on = [kubernetes_secret_v1.csi-cephfs-secret]
}
