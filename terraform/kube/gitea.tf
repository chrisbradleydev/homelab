# Gitea, the internal Git forge at https://git.internal.touchgrass.software,
# with SSH at ssh.internal.touchgrass.software. Chart 12.7.0 ships Gitea
# 1.27. As of 2026-10-12, no chart release supports Gitea 28.
# app.ini on the volume holds the generated SECRET_KEY and INTERNAL_TOKEN.
# Gitea encrypts two-factor secrets with SECRET_KEY, so a backup must
# include app.ini as well as the repositories.
resource "helm_release" "gitea" {
  name       = "gitea"
  repository = "https://dl.gitea.com/charts/"
  chart      = "gitea"
  namespace  = module.gitea_namespace.name
  version    = "12.7.0"
  values     = [file("gitea.yaml")]
  depends_on = [helm_release.gitea-extras, helm_release.gitea-pg, helm_release.gitea-valkey, helm_release.gateway]
}
