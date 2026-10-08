{{- define "<CHARTNAME>.env" -}}
- name: SERVICE_NAME
  value: {{ include "pc-lib.fullname" . | quote }}
- name: SERVICE_VERSION
  value: {{ .Chart.AppVersion | quote }}
- name: DEPLOY_ENV
  value: {{ default .Values.config.environment (default (dict) .Values.global).environment | quote }}
- name: LOG_LEVEL
  value: {{ .Values.config.logLevel | quote }}
{{ include "pc-lib.otelEnv" . }}
{{- end -}}
