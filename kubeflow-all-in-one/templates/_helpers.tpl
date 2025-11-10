{{/*
Expand the name of the chart.
*/}}
{{- define "kubeflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kubeflow.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
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
{{- define "kubeflow.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kubeflow.labels" -}}
helm.sh/chart: {{ include "kubeflow.chart" . }}
{{ include "kubeflow.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kubeflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubeflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component labels
*/}}
{{- define "kubeflow.componentLabels" -}}
{{- $component := .component -}}
{{- $context := .context -}}
app.kubernetes.io/name: {{ $component }}
app.kubernetes.io/instance: {{ $context.Release.Name }}
app.kubernetes.io/component: {{ $component }}
app.kubernetes.io/part-of: kubeflow
app.kubernetes.io/managed-by: {{ $context.Release.Service }}
{{- with $context.Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
ArgoCD sync wave annotation
*/}}
{{- define "kubeflow.syncWave" -}}
{{- if .Values.argocd.enabled }}
argocd.argoproj.io/sync-wave: {{ . | quote }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "kubeflow.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Kubeflow namespace
*/}}
{{- define "kubeflow.namespace" -}}
{{- .Values.namespace.name | default "kubeflow" }}
{{- end }}

{{/*
Auth namespace
*/}}
{{- define "kubeflow.authNamespace" -}}
auth
{{- end }}

{{/*
OAuth2 Proxy namespace
*/}}
{{- define "kubeflow.oauth2ProxyNamespace" -}}
oauth2-proxy
{{- end }}

{{/*
Istio system namespace
*/}}
{{- define "kubeflow.istioNamespace" -}}
{{- .Values.global.istioGatewayNamespace | default "istio-system" }}
{{- end }}

{{/*
Knative serving namespace
*/}}
{{- define "kubeflow.knativeNamespace" -}}
knative-serving
{{- end }}

{{/*
Storage class
*/}}
{{- define "kubeflow.storageClass" -}}
{{- .Values.global.storageClass | default "longhorn" }}
{{- end }}

{{/*
Istio gateway name
*/}}
{{- define "kubeflow.gatewayName" -}}
{{- .Values.global.istioGatewayName | default "kubeflow-gateway" }}
{{- end }}

{{/*
Domain
*/}}
{{- define "kubeflow.domain" -}}
{{- .Values.global.domain | default "kubeflow.example.com" }}
{{- end }}

{{/*
TLS secret name
*/}}
{{- define "kubeflow.tlsSecretName" -}}
{{- .Values.global.tlsSecretName | default "kubeflow-tls-cert" }}
{{- end }}

{{/*
Cert manager issuer
*/}}
{{- define "kubeflow.certIssuer" -}}
{{- .Values.global.certManagerIssuer | default "letsencrypt-prod" }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "kubeflow.serviceAccountName" -}}
{{- $component := .component -}}
{{- $context := .context -}}
{{- printf "%s-sa" $component }}
{{- end }}

{{/*
Image pull policy
*/}}
{{- define "kubeflow.imagePullPolicy" -}}
{{- .Values.imagePullPolicy | default "IfNotPresent" }}
{{- end }}

{{/*
Resource requirements
*/}}
{{- define "kubeflow.resources" -}}
{{- if . }}
resources:
  {{- if .requests }}
  requests:
    {{- if .requests.cpu }}
    cpu: {{ .requests.cpu }}
    {{- end }}
    {{- if .requests.memory }}
    memory: {{ .requests.memory }}
    {{- end }}
  {{- end }}
  {{- if .limits }}
  limits:
    {{- if .limits.cpu }}
    cpu: {{ .limits.cpu }}
    {{- end }}
    {{- if .limits.memory }}
    memory: {{ .limits.memory }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Node selector
*/}}
{{- define "kubeflow.nodeSelector" -}}
{{- if .Values.nodeSelector }}
nodeSelector:
  {{- toYaml .Values.nodeSelector | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Tolerations
*/}}
{{- define "kubeflow.tolerations" -}}
{{- if .Values.tolerations }}
tolerations:
  {{- toYaml .Values.tolerations | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Affinity
*/}}
{{- define "kubeflow.affinity" -}}
{{- if .Values.affinity }}
affinity:
  {{- toYaml .Values.affinity | nindent 2 }}
{{- end }}
{{- end }}

