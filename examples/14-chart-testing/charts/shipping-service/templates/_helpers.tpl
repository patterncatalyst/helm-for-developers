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

{{/* Name of the Secret holding PG_PASSWORD (existing or chart-created). Empty when unused. */}}
{{- define "shipping-service.pgSecret" -}}
{{- if .Values.postgres.existingSecret -}}
{{- .Values.postgres.existingSecret -}}
{{- else if .Values.postgres.password -}}
{{- include "shipping-service.fullname" . -}}
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
{{ include "shipping-service.otelEnv" . }}
{{- end -}}

{{/*
Naming and labels. Every helper takes the consuming chart's root context.
*/}}
{{- define "shipping-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

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
app.kubernetes.io/part-of: {{ default "shipping-platform" (default (dict) .Values.global).partOf }}
{{- end -}}

{{/*
Image reference: [global.imageRegistry/]repository:tag, tag defaults to .Chart.AppVersion.
*/}}
{{- define "shipping-service.image" -}}
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
{{- define "shipping-service.metadataAnnotations" -}}
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
OpenShift-safe security: runAsNonRoot, no runAsUser/fsGroup (restricted-v2 assigns
the UID range), no privilege escalation, all capabilities dropped, seccomp default.
*/}}
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

{{/*
Health probes. /health is liveness, /healthz is readiness. A startupProbe gates both
(default 30 x 2s = 60s) so a slow Python import does not trigger a liveness kill.
*/}}
{{- define "shipping-service.probes" -}}
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
OpenTelemetry environment. The endpoint comes from .Values.otel.endpoint, falling back
to .Values.global.otlpEndpoint. With no endpoint, the SDK stays disabled.
*/}}
{{- define "shipping-service.otelEnv" -}}
{{- $global := default (dict) .Values.global -}}
{{- $endpoint := default (default "" $global.otlpEndpoint) .Values.otel.endpoint -}}
{{- $svc := default (include "shipping-service.fullname" .) .Values.otel.serviceName -}}
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

