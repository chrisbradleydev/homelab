{{- define "cluster-base.labels" -}}
app.kubernetes.io/name: cluster-base
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: touchgrass-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
