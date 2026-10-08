{{/*
Deployment. Call with a dict:
  root:           the chart root context (.)
  env:            YAML list string of container env entries
  envFrom:        YAML list string of envFrom entries (optional)
  podAnnotations: dict of extra pod annotations, e.g. checksum/config (optional)
*/}}
{{- define "pc-lib.deployment" -}}
{{- $root := .root -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "pc-lib.fullname" $root }}
  labels:
    {{- include "pc-lib.labels" $root | nindent 4 }}
  {{- with (include "pc-lib.metadataAnnotations" $root | trim) }}
  annotations:
    {{- . | nindent 4 }}
  {{- end }}
spec:
  replicas: {{ $root.Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "pc-lib.selectorLabels" $root | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "pc-lib.labels" $root | nindent 8 }}
      annotations:
        {{- with (include "pc-lib.metadataAnnotations" $root | trim) }}
        {{- . | nindent 8 }}
        {{- end }}
        {{- range $k, $v := (default (dict) .podAnnotations) }}
        {{ $k | quote }}: {{ $v | quote }}
        {{- end }}
        {{- range $k, $v := (default (dict) $root.Values.podAnnotations) }}
        {{ $k | quote }}: {{ $v | quote }}
        {{- end }}
    spec:
      {{- with $root.Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- include "pc-lib.podSecurityContext" $root | nindent 8 }}
      containers:
        - name: {{ include "pc-lib.name" $root }}
          image: {{ include "pc-lib.image" $root | quote }}
          imagePullPolicy: {{ $root.Values.image.pullPolicy }}
          securityContext:
            {{- include "pc-lib.containerSecurityContext" $root | nindent 12 }}
          ports:
            - name: http
              containerPort: {{ $root.Values.containerPort }}
              protocol: TCP
          {{- with .envFrom }}
          envFrom:
            {{- . | nindent 12 }}
          {{- end }}
          env:
            {{- .env | nindent 12 }}
          {{- include "pc-lib.probes" $root | nindent 10 }}
          resources:
            {{- toYaml $root.Values.resources | nindent 12 }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
{{- end -}}
