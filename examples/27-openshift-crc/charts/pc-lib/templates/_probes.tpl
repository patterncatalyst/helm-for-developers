{{/*
Health probes. /health is liveness, /healthz is readiness. A startupProbe gates both
(default 30 x 2s = 60s) so a slow Python import does not trigger a liveness kill.
*/}}
{{- define "pc-lib.probes" -}}
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
