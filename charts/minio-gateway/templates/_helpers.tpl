{{/*
Expand the name of the chart.
*/}}
{{- define "minio-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "minio-gateway.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "minio-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "minio-gateway.labels" -}}
helm.sh/chart: {{ include "minio-gateway.chart" . }}
{{ include "minio-gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "minio-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "minio-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "minio-gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "minio-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "minio-gateway.rootUser.secretName" -}}
{{- default (include "minio-gateway.fullname" .) .Values.rootUser.existingSecret.name }}
{{- end }}

{{- define "minio-gateway.rootUser.secretUserKey" -}}
{{- if .Values.rootUser.existingSecret.name }}
{{- .Values.rootUser.existingSecret.userKey }}
{{- else -}}
root-user
{{- end }}
{{- end }}

{{- define "minio-gateway.rootUser.secretPasswordKey" -}}
{{- if .Values.rootUser.existingSecret.name }}
{{- .Values.rootUser.existingSecret.passwordKey }}
{{- else -}}
root-password
{{- end }}
{{- end }}
