# This release installs the snapshot-controller and the VolumeSnapshot CRDs.
# The csi-snapshotter sidecar in the ceph-csi-rbd provisioner needs the CRDs.
# The chart renders the CRDs as templates, so a new chart version upgrades them.
resource "helm_release" "snapshot-controller" {
  name       = "snapshot-controller"
  repository = "https://piraeus.io/helm-charts/"
  chart      = "snapshot-controller"
  namespace  = "kube-system"
  version    = "5.3.0"
  values = [
    yamlencode({
      # helm uninstall leaves the CRDs and the snapshots in them.
      keepCRDs = true
    })
  ]
}
