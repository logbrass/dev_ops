{{- define "jarvis-auth.name" -}}{{ default .Chart.Name .Values.nameOverride }}{{- end -}}
{{- define "jarvis-auth.fullname" -}}{{ printf "%s-%s" .Release.Name (include "jarvis-auth.name" .) | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "jarvis-auth.labels" -}}
app.kubernetes.io/name: {{ include "jarvis-auth.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
{{- define "jarvis-auth.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jarvis-auth.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
