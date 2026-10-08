{{/*
Service name of an aliased subchart, matching pc-lib.fullname in the subchart
(alias is the subchart's chart name).
*/}}
{{- define "shipping-platform.svcName" -}}
{{- $alias := .alias -}}
{{- $vals := index .root.Values $alias | default dict -}}
{{- if $vals.fullnameOverride -}}
{{- $vals.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default $alias $vals.nameOverride -}}
{{- if contains $name .root.Release.Name -}}
{{- .root.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .root.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
