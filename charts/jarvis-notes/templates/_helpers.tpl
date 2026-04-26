{{- define "jarvis-notes.name" -}}{{ default .Chart.Name .Values.nameOverride }}{{- end -}}
{{- define "jarvis-notes.fullname" -}}{{ printf "%s-%s" .Release.Name (include "jarvis-notes.name" .) | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- define "jarvis-notes.labels" -}}
app.kubernetes.io/name: {{ include "jarvis-notes.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
{{- define "jarvis-notes.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jarvis-notes.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
