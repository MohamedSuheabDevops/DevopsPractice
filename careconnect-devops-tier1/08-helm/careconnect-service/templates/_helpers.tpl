{{/* Name of the release's resources: just the release name (keeps names short) */}}
{{- define "careconnect-service.fullname" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels used to SELECT pods (must never change after first install) */}}
{{- define "careconnect-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "careconnect-service.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Standard labels */}}
{{- define "careconnect-service.labels" -}}
{{ include "careconnect-service.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
