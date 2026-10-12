{{- define "gitea-extras.labels" -}}
app.kubernetes.io/name: gitea-extras
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: touchgrass-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
