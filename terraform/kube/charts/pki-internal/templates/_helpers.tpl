{{- define "pki-internal.labels" -}}
app.kubernetes.io/name: pki-internal
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: touchgrass-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
