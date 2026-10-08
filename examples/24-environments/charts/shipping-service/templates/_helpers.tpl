{{/* Effective deployment environment: global.environment, else config.environment. */}}
{{- define "shipping-service.environment" -}}
{{- default .Values.config.environment (default (dict) .Values.global).environment -}}
{{- end -}}

{{/* Name of the Secret holding API_TOKEN (existing or chart-created). Empty when unused. */}}
{{- define "shipping-service.tokenSecret" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else if .Values.auth.token -}}
{{- include "pc-lib.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Name of the Secret holding PG_PASSWORD (existing or chart-created). Empty when unused. */}}
{{- define "shipping-service.pgSecret" -}}
{{- if .Values.postgres.existingSecret -}}
{{- .Values.postgres.existingSecret -}}
{{- else if .Values.postgres.password -}}
{{- include "pc-lib.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* PG_* container env entries (shared by the Deployment and the migration Job). */}}
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
      name: {{ include "pc-lib.fullname" . }}
      key: pg-password
{{- end }}
{{- end }}
{{- end -}}

{{/* Container env for the Deployment. */}}
{{- define "shipping-service.env" -}}
{{- if eq .Values.config.storage "postgres" }}
{{ include "shipping-service.pgEnv" . }}
{{- end }}
{{- if .Values.kafka.enabled }}
- name: KAFKA_BOOTSTRAP
  value: {{ required "kafka.bootstrap is required when kafka.enabled=true" .Values.kafka.bootstrap | quote }}
{{- end }}
{{- if (include "shipping-service.tokenSecret" .) }}
- name: API_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "shipping-service.tokenSecret" . }}
      key: {{ if .Values.auth.existingSecret }}{{ .Values.auth.existingSecretKey }}{{ else }}api-token{{ end }}
{{- end }}
{{ include "pc-lib.otelEnv" . }}
{{- end -}}
