{{/*
Expand the name of the chart.
*/}}
{{- define "messages.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "messages.fullname" -}}
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
{{- define "messages.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
messages.labels
*/}}
{{- define "messages.labels" -}}
helm.sh/chart: {{ include "messages.chart" . }}
{{ include "messages.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "messages.selectorLabels" -}}
app.kubernetes.io/name: {{ include "messages.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
transform dictionary of environment variables
Usage : {{ include "messages.env.transformDict" .Values.envVars }}

Example:
envVars:
  # Using simple strings as env vars
  ENV_VAR_NAME: "envVar value"
  # Using a value from a configMap
  ENV_VAR_FROM_CM:
    configMapKeyRef:
      name: cm-name
      key: "key_in_cm"
  # Using a value from a secret
  ENV_VAR_FROM_SECRET:
    secretKeyRef:
      name: secret-name
      key: "key_in_secret"
*/}}
{{- define "messages.env.transformDict" -}}
{{- range $key, $value := . }}
- name: {{ $key | quote }}
{{- if $value | kindIs "map" }}
  valueFrom: {{ $value | toYaml | nindent 4 }}
{{- else }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}


{{/*
messages env vars
*/}}
{{- define "messages.common.env" -}}
{{- $topLevelScope := index . 0 -}}
{{- $workerScope := index . 1 -}}
{{- include "messages.env.transformDict" $workerScope.envVars -}}
{{- end }}

{{/*
messages backend django env vars - combines common backend.envVars with backend.django.envVars
*/}}
{{- define "messages.backend.django.env" -}}
{{- $topLevelScope := index . 0 -}}
{{- $workerScope := index . 1 -}}
{{- include "messages.env.transformDict" $workerScope.envVars -}}
{{- include "messages.env.transformDict" (($workerScope.django | default dict).envVars | default dict) -}}
{{- end }}

{{/*
messages celery env vars - combines common backend.envVars with backend.celery.envVars
*/}}
{{- define "messages.backend.celery.env" -}}
{{- $topLevelScope := index . 0 -}}
{{- $workerScope := index . 1 -}}
{{- include "messages.env.transformDict" $workerScope.envVars -}}
{{- include "messages.env.transformDict" ($workerScope.celery.envVars | default dict) -}}
{{- end }}

{{/*
Common labels

Requires array with top level scope and component name
*/}}
{{- define "messages.common.labels" -}}
{{- $topLevelScope := index . 0 -}}
{{- $component := index . 1 -}}
{{- include "messages.labels" $topLevelScope }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Common selector labels

Requires array with top level scope and component name
*/}}
{{- define "messages.common.selectorLabels" -}}
{{- $topLevelScope := index . 0 -}}
{{- $component := index . 1 -}}
{{- include "messages.selectorLabels" $topLevelScope }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{- define "messages.probes.abstract" -}}
{{- if .exec -}}
exec:
{{- toYaml .exec | nindent 2 }}
{{- else if .tcpSocket -}}
tcpSocket:
{{- toYaml .tcpSocket | nindent 2 }}
{{- else -}}
httpGet:
  path: {{ .path }}
  port: {{ .targetPort }}
{{- end }}
initialDelaySeconds: {{ .initialDelaySeconds | eq nil | ternary 0 .initialDelaySeconds }}
timeoutSeconds: {{ .timeoutSeconds | eq nil | ternary 1 .timeoutSeconds }}
{{- end }}

{{/*
Full name for the backend

Requires top level scope
*/}}
{{- define "messages.backend.fullname" -}}
{{ include "messages.fullname" . }}-backend
{{- end }}

{{/*
Full name for the frontend

Requires top level scope
*/}}
{{- define "messages.frontend.fullname" -}}
{{ include "messages.fullname" . }}-frontend
{{- end }}

{{/*
Full name for the inbound MTA

Requires top level scope
*/}}
{{- define "messages.mtaIn.fullname" -}}
{{ include "messages.fullname" . }}-mta-in
{{- end }}

{{/*
Full name for the MPA (rspamd)

Requires top level scope
*/}}
{{- define "messages.mpa.fullname" -}}
{{ include "messages.fullname" . }}-mpa
{{- end }}

{{/*
Full name for the Celery Worker

Requires top level scope
*/}}


{{- define "messages.celery.worker.fullname" -}}
{{ include "messages.fullname" . }}-celery-worker
{{- end }}

{{/*
Usage : {{ include "messages.secret.dockerconfigjson.name" (dict "fullname" (include "messages.fullname" .) "imageCredentials" .Values.path.to.the.image1) }}
*/}}
{{- define "messages.secret.dockerconfigjson.name" }}
{{- if (default (dict) .imageCredentials).name }}{{ .imageCredentials.name }}{{ else }}{{ .fullname | trunc 63 | trimSuffix "-" }}-dockerconfig{{ end -}}
{{- end }}

{{/*
Usage : {{ include "messages.secret.dockerconfigjson" (dict "fullname" (include "messages.fullname" .) "imageCredentials" .Values.path.to.the.image1) }}
*/}}
{{- define "messages.secret.dockerconfigjson" }}
{{- if .imageCredentials -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ template "messages.secret.dockerconfigjson.name" (dict "fullname" .fullname "imageCredentials" .imageCredentials) }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {{ template "messages.secret.dockerconfigjson.data" .imageCredentials }}
{{- end -}}
{{- end }}
