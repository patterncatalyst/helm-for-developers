{{/* Chart name, overridable, DNS-safe. */}}
{{- define "shipping-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Resource name: <release>-<chart> unless the release name already contains the chart
name. fullnameOverride wins. Truncated to 63 characters (the DNS label limit).
*/}}
{{- define "shipping-service.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Chart name and version for the helm.sh/chart label ("+" is not valid in a label). */}}
{{- define "shipping-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels that never change after install: they feed the Deployment selector. */}}
{{- define "shipping-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shipping-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Recommended labels. */}}
{{- define "shipping-service.labels" -}}
helm.sh/chart: {{ include "shipping-service.chart" . }}
{{ include "shipping-service.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ default "shipping-platform" (default (dict) .Values.global).partOf }}
{{- end -}}

{{/* Effective deployment environment: global.environment, else config.environment. */}}
{{- define "shipping-service.environment" -}}
{{- default .Values.config.environment (default (dict) .Values.global).environment -}}
{{- end -}}

{{/* Name of the Secret holding API_TOKEN, or empty when the API is open. */}}
{{- define "shipping-service.tokenSecret" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else if or .Values.auth.token .Values.auth.generate -}}
{{- include "shipping-service.fullname" . -}}
{{- end -}}
{{- end -}}
