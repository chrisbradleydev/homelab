output "name" {
  description = "Namespace name, for depends_on and namespace arguments"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}
