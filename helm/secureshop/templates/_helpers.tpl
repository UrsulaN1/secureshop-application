{{- define "secureshop.name" -}}
secureshop
{{- end -}}

{{- define "secureshop.labels" -}}
app.kubernetes.io/name: {{ include "secureshop.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
