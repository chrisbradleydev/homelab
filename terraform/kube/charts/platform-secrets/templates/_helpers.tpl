{{- define "platform-secrets.labels" -}}
app.kubernetes.io/name: platform-secrets
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: touchgrass-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
