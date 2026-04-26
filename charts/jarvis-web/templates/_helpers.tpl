{{/* Common helpers shared by all jarvis-web templates. */}}

{{- define "jarvis-web.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "jarvis-web.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "jarvis-web.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "jarvis-web.labels" -}}
app.kubernetes.io/name: {{ include "jarvis-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "jarvis-web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jarvis-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
