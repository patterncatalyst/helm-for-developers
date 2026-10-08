{{/*
Image reference: [global.imageRegistry/]repository:tag, tag defaults to .Chart.AppVersion.
*/}}
{{- define "pc-lib.image" -}}
{{- $global := default (dict) .Values.global -}}
{{- $registry := default "" $global.imageRegistry -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" ($registry | trimSuffix "/") .Values.image.repository $tag -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}
{{- end -}}
