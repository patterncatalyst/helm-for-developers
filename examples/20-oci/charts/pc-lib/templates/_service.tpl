{{- define "pc-lib.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "pc-lib.fullname" . }}
  labels:
    {{- include "pc-lib.labels" . | nindent 4 }}
  {{- with (include "pc-lib.metadataAnnotations" . | trim) }}
  annotations:
    {{- . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      {{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
      nodePort: {{ .Values.service.nodePort }}
      {{- end }}
  selector:
    {{- include "pc-lib.selectorLabels" . | nindent 4 }}
{{- end -}}
