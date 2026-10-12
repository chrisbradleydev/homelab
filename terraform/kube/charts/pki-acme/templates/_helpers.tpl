{{- define "pki-acme.labels" -}}
app.kubernetes.io/name: pki-acme
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: touchgrass-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
