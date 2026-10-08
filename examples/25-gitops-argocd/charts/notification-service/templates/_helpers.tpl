{{- define "notification-service.environment" -}}
{{- default .Values.config.environment (default (dict) .Values.global).environment -}}
{{- end -}}

{{- define "notification-service.env" -}}
- name: KAFKA_BOOTSTRAP
  value: {{ required "kafka.bootstrap is required" .Values.kafka.bootstrap | quote }}
{{ include "pc-lib.otelEnv" . }}
{{- end -}}
