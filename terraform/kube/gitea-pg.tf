# The Gitea database: two PostgreSQL instances, a PgBouncer pooler, the
# server certificate, daily volume snapshots and the network policies
resource "helm_release" "gitea-pg" {
  name      = "gitea-pg"
  chart     = "./charts/postgres"
  namespace = module.gitea_namespace.name
  values    = [file("gitea-pg.yaml")]
  set = [
    {
      # helm_release doesn't notice template edits in a local chart unless a
      # value changes, so pass a hash of every file in the chart.
      name  = "checksum"
      value = sha1(join("", [for f in sort(fileset("${path.module}/charts/postgres", "**")) : filesha1("${path.module}/charts/postgres/${f}")]))
    },
  ]
  depends_on = [helm_release.pg-operator, helm_release.pki-internal, helm_release.cluster-base]
}
