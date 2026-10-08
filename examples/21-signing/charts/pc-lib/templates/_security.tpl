{{/*
OpenShift-safe security: runAsNonRoot, no runAsUser/fsGroup (restricted-v2 assigns
the UID range), no privilege escalation, all capabilities dropped, seccomp default.
*/}}
{{- define "pc-lib.podSecurityContext" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "pc-lib.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
capabilities:
  drop:
    - ALL
seccompProfile:
  type: RuntimeDefault
{{- end -}}
