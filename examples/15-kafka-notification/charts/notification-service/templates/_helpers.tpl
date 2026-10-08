{{/* Shared naming, labels, image, probes, security and OTel helpers. */}}
{{/*
Naming and labels. Every helper takes the consuming chart's root context.
*/}}
{{- define "notification-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "notification-service.fullname" -}}
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

{{- define "notification-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "notification-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "notification-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "notification-service.labels" -}}
helm.sh/chart: {{ include "notification-service.chart" . }}
{{ include "notification-service.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ default "shipping-platform" (default (dict) .Values.global).partOf }}
{{- end -}}

{{/*
Image reference: [global.imageRegistry/]repository:tag, tag defaults to .Chart.AppVersion.
*/}}
{{- define "notification-service.image" -}}
{{- $global := default (dict) .Values.global -}}
{{- $registry := default "" $global.imageRegistry -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" ($registry | trimSuffix "/") .Values.image.repository $tag -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}
{{- end -}}

{{/*
Data-product metadata annotations (data-mesh style ownership).
Values: .Values.dataProduct.{domain,owner,name}. Omitted keys are skipped.
*/}}
{{- define "notification-service.metadataAnnotations" -}}
{{- with .Values.dataProduct }}
{{- if .domain }}
patterncatalyst.io/domain: {{ .domain | quote }}
{{- end }}
{{- if .owner }}
patterncatalyst.io/owner: {{ .owner | quote }}
{{- end }}
{{- if .name }}
patterncatalyst.io/data-product: {{ .name | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Health probes. /health is liveness, /healthz is readiness. A startupProbe gates both
(default 30 x 2s = 60s) so a slow Python import does not trigger a liveness kill.
*/}}
{{- define "notification-service.probes" -}}
startupProbe:
  httpGet:
    path: {{ .Values.probes.startup.path }}
    port: http
  failureThreshold: {{ .Values.probes.startup.failureThreshold }}
  periodSeconds: {{ .Values.probes.startup.periodSeconds }}
livenessProbe:
  httpGet:
    path: {{ .Values.probes.liveness.path }}
    port: http
  periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
readinessProbe:
  httpGet:
    path: {{ .Values.probes.readiness.path }}
    port: http
  periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
{{- end -}}

{{/*
OpenShift-safe security: runAsNonRoot, no runAsUser/fsGroup (restricted-v2 assigns
the UID range), no privilege escalation, all capabilities dropped, seccomp default.
*/}}
{{- define "notification-service.podSecurityContext" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "notification-service.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
capabilities:
  drop:
    - ALL
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{/*
OpenTelemetry environment. The endpoint comes from .Values.otel.endpoint, falling back
to .Values.global.otlpEndpoint. With no endpoint, the SDK stays disabled.
*/}}
{{- define "notification-service.otelEnv" -}}
{{- $global := default (dict) .Values.global -}}
{{- $endpoint := default (default "" $global.otlpEndpoint) .Values.otel.endpoint -}}
{{- $svc := default (include "notification-service.fullname" .) .Values.otel.serviceName -}}
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

{{- define "notification-service.environment" -}}
{{- default .Values.config.environment (default (dict) .Values.global).environment -}}
{{- end -}}

{{- define "notification-service.env" -}}
- name: KAFKA_BOOTSTRAP
  value: {{ required "kafka.bootstrap is required" .Values.kafka.bootstrap | quote }}
{{ include "notification-service.otelEnv" . }}
{{- end -}}
