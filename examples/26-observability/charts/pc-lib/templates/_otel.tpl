{{/*
OpenTelemetry environment. The endpoint comes from .Values.otel.endpoint, falling back
to .Values.global.otlpEndpoint. With no endpoint, the SDK stays disabled.
*/}}
{{- define "pc-lib.otelEnv" -}}
{{- $global := default (dict) .Values.global -}}
{{- $endpoint := default (default "" $global.otlpEndpoint) .Values.otel.endpoint -}}
{{- $svc := default (include "pc-lib.fullname" .) .Values.otel.serviceName -}}
- name: OTEL_SDK_DISABLED
  value: {{ if $endpoint }}"false"{{ else }}"true"{{ end }}
{{- if $endpoint }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ $endpoint | quote }}
{{- end }}
- name: OTEL_SERVICE_NAME
  value: {{ $svc | quote }}
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ printf "service.namespace=%s,deployment.environment=%s,service.version=%s" (default "shipping" (dig "domain" "" (default (dict) .Values.dataProduct))) (default "dev" $global.environment) .Chart.AppVersion | quote }}
{{- end -}}
