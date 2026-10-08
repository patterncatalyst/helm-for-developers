{{/*
Data-product metadata annotations (data-mesh style ownership).
Values: .Values.dataProduct.{domain,owner,name}. Omitted keys are skipped.
*/}}
{{- define "pc-lib.metadataAnnotations" -}}
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
