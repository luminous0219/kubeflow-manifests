{{/*
Expand the name of the chart.
*/}}
{{- define "template.name" -}}
{{- default .Values.app.name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "template.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Values.app.name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "template.chart" -}}
{{- printf "%s-%s" .Values.app.name .Values.app.chartVersion | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "template.labels" -}}
helm.sh/chart: {{ include "template.chart" . }}
{{ include "template.selectorLabels" . }}
{{- if .Values.app.version }}
app.kubernetes.io/version: {{ .Values.app.version | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "template.selectorLabels" -}}
app.kubernetes.io/name: {{ include "template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "template.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "template.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "template.secretName" -}}
{{- if .Values.existingSecret }}
{{- .Values.existingSecret }}
{{- else }}
{{- include "template.fullname" . }}-secrets
{{- end }}
{{- end }}

{{/*
Generate certificates secret name
*/}}
{{- define "template.certificateSecretName" -}}
{{- .Values.certManager.secretName | default (printf "%s-tls-cert" (include "template.fullname" .)) }}
{{- end }}

{{/*
Common Istio labels for service mesh
*/}}
{{- define "template.istioLabels" -}}
app: {{ include "template.name" . }}
version: {{ .Values.app.version | quote }}
{{- end }}

{{/*
Generate PVC name
*/}}
{{- define "template.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- include "template.fullname" . }}-pvc
{{- end }}
{{- end }}

{{/*
Generate namespace name
*/}}
{{- define "template.namespace" -}}
{{- .Values.namespace.name | default .Release.Namespace }}
{{- end }}

{{/*
Generate gateway name
*/}}
{{- define "template.gatewayName" -}}
{{- .Values.istio.gateway.name | default (printf "%s-gateway" (include "template.fullname" .)) }}
{{- end }}

{{/*
Generate virtual service name
*/}}
{{- define "template.virtualServiceName" -}}
{{- printf "%s-vs" (include "template.fullname" .) }}
{{- end }}

{{/*
Generate destination rule name
*/}}
{{- define "template.destinationRuleName" -}}
{{- printf "%s-dr" (include "template.fullname" .) }}
{{- end }} 