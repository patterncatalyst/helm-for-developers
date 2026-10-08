{{/* Chart name, overridable. */}}
{{- define "shipping-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* <release>-<chart>, or just the release name when it already contains the chart name. */}}
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

{{- define "shipping-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shipping-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shipping-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "shipping-service.labels" -}}
helm.sh/chart: {{ include "shipping-service.chart" . }}
{{ include "shipping-service.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* [global.imageRegistry/]repository:tag, tag defaults to .Chart.AppVersion. */}}
{{- define "shipping-service.image" -}}
{{- $registry := default "" (default (dict) .Values.global).imageRegistry -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" ($registry | trimSuffix "/") .Values.image.repository $tag -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}
{{- end -}}

{{/* Effective deployment environment: global.environment, else config.environment. */}}
{{- define "shipping-service.environment" -}}
{{- default .Values.config.environment (default (dict) .Values.global).environment -}}
{{- end -}}

{{/* Name of the Secret holding API_TOKEN (existing or chart-created). Empty when unused. */}}
{{- define "shipping-service.tokenSecret" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else if .Values.auth.token -}}
{{- include "shipping-service.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* PG_* container env entries. */}}
{{- define "shipping-service.pgEnv" -}}
- name: PG_HOST
  value: {{ required "postgres.host is required when config.storage=postgres" .Values.postgres.host | quote }}
- name: PG_PORT
  value: {{ .Values.postgres.port | quote }}
- name: PG_SCHEMA
  value: {{ .Values.postgres.schema | quote }}
{{- if .Values.postgres.existingSecret }}
- name: PG_DATABASE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret }}
      key: {{ .Values.postgres.existingSecretKeys.database }}
- name: PG_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret }}
      key: {{ .Values.postgres.existingSecretKeys.user }}
- name: PG_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgres.existingSecret }}
      key: {{ .Values.postgres.existingSecretKeys.password }}
{{- else }}
- name: PG_DATABASE
  value: {{ .Values.postgres.database | quote }}
- name: PG_USER
  value: {{ .Values.postgres.user | quote }}
{{- if .Values.postgres.password }}
- name: PG_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "shipping-service.fullname" . }}
      key: pg-password
{{- end }}
{{- end }}
{{- end -}}

{{/* Container env for the Deployment. */}}
{{- define "shipping-service.env" -}}
{{- if eq .Values.config.storage "postgres" }}
{{ include "shipping-service.pgEnv" . }}
{{- end }}
{{- if (include "shipping-service.tokenSecret" .) }}
- name: API_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "shipping-service.tokenSecret" . }}
      key: {{ if .Values.auth.existingSecret }}{{ .Values.auth.existingSecretKey }}{{ else }}api-token{{ end }}
{{- end }}
{{- end -}}

{{- define "shipping-service.podSecurityContext" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "shipping-service.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
capabilities:
  drop:
    - ALL
seccompProfile:
  type: RuntimeDefault
{{- end -}}
