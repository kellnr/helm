{{/*
Expand the name of the chart.
*/}}
{{- define "kellnr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kellnr.fullname" -}}
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
{{- define "kellnr.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kellnr.labels" -}}
helm.sh/chart: {{ include "kellnr.chart" . }}
{{ include "kellnr.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kellnr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kellnr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kellnr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kellnr.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Decide the proxy port number to use if set to auto
*/}}
{{- define "kellnr.serviceOriginPort" -}}
{{- if eq .Values.kellnr.origin.protocol "https" }}
{{- default 443 .Values.kellnr.origin.port }}
{{- else }}
{{- default 80 .Values.kellnr.origin.port }}
{{- end }}
{{- end }}

{{/*
Cookie signing key used by Kellnr.
- If user provided a value, enforce min length (>= 64 bytes/chars) and return it.
- If not provided, return empty string so the env var can be omitted entirely.

Note: Helm templates don't have a "bytes" unit here; we can only validate string length.
*/}}
{{- define "kellnr.cookieSigningKey" -}}
{{- $key := default "" .Values.kellnr.registry.cookieSecret.cookieSigningKey -}}
{{- if ne $key "" -}}
  {{- if lt (len $key) 64 -}}
    {{- fail "kellnr.registry.cookieSecret.cookieSigningKey must be at least 64 characters" -}}
  {{- end -}}
  {{- $key -}}
{{- else -}}
  {{- "" -}}
{{- end -}}
{{- end }}

{{/*
Generate Kellnr environment variables.
Only generate variables if they are explicitly set (not null) in values.yaml.
Note: We avoid using "{{- if" and "{{- end" inside to prevent stripping newlines between variables.
*/}}
{{- define "kellnr.envVars" -}}
{{ if not (eq .Values.kellnr.setup.adminPwd nil) }}
KELLNR_SETUP__ADMIN_PWD: {{ .Values.kellnr.setup.adminPwd | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.setup.adminToken nil) }}
KELLNR_SETUP__ADMIN_TOKEN: {{ .Values.kellnr.setup.adminToken | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.dataDir nil) }}
KELLNR_REGISTRY__DATA_DIR: {{ .Values.kellnr.registry.dataDir | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.sessionAgeSeconds nil) }}
KELLNR_REGISTRY__SESSION_AGE_SECONDS: {{ .Values.kellnr.registry.sessionAgeSeconds | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.cacheSize nil) }}
KELLNR_REGISTRY__CACHE_SIZE: {{ .Values.kellnr.registry.cacheSize | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.maxCrateSize nil) }}
KELLNR_REGISTRY__MAX_CRATE_SIZE: {{ .Values.kellnr.registry.maxCrateSize | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.maxDbConnections nil) }}
KELLNR_REGISTRY__MAX_DB_CONNECTIONS: {{ .Values.kellnr.registry.maxDbConnections | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.authRequired nil) }}
KELLNR_REGISTRY__AUTH_REQUIRED: {{ .Values.kellnr.registry.authRequired | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.allowOwnerlessCrates nil) }}
KELLNR_REGISTRY__ALLOW_OWNERLESS_CRATES: {{ .Values.kellnr.registry.allowOwnerlessCrates | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.token.cache.enabled nil) }}
KELLNR_REGISTRY__TOKEN_CACHE_ENABLED: {{ .Values.kellnr.registry.token.cache.enabled | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.token.cache.ttlSeconds nil) }}
KELLNR_REGISTRY__TOKEN_CACHE_TTL_SECONDS: {{ .Values.kellnr.registry.token.cache.ttlSeconds | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.token.cache.maxCapacity nil) }}
KELLNR_REGISTRY__TOKEN_CACHE_MAX_CAPACITY: {{ .Values.kellnr.registry.token.cache.maxCapacity | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.token.db.retryCount nil) }}
KELLNR_REGISTRY__TOKEN_DB_RETRY_COUNT: {{ .Values.kellnr.registry.token.db.retryCount | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.token.db.retryDelayMs nil) }}
KELLNR_REGISTRY__TOKEN_DB_RETRY_DELAY_MS: {{ .Values.kellnr.registry.token.db.retryDelayMs | quote }}
{{ end }}
{{ $cookieKey := include "kellnr.cookieSigningKey" . }}
{{ if ne $cookieKey "" }}
KELLNR_REGISTRY__COOKIE_SIGNING_KEY: {{ $cookieKey | quote }}
{{ end }}
{{ if .Values.kellnr.registry.requiredCrateFields }}
KELLNR_REGISTRY__REQUIRED_CRATE_FIELDS: {{ .Values.kellnr.registry.requiredCrateFields | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.registry.newCratesRestricted nil) }}
KELLNR_REGISTRY__NEW_CRATES_RESTRICTED: {{ .Values.kellnr.registry.newCratesRestricted | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.docs.enabled nil) }}
KELLNR_DOCS__ENABLED: {{ .Values.kellnr.docs.enabled | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.docs.maxSize nil) }}
KELLNR_DOCS__MAX_SIZE: {{ .Values.kellnr.docs.maxSize | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.proxy.enabled nil) }}
KELLNR_PROXY__ENABLED: {{ .Values.kellnr.proxy.enabled | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.proxy.numThreads nil) }}
KELLNR_PROXY__NUM_THREADS: {{ .Values.kellnr.proxy.numThreads | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.proxy.downloadOnUpdate nil) }}
KELLNR_PROXY__DOWNLOAD_ON_UPDATE: {{ .Values.kellnr.proxy.downloadOnUpdate | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.log.level nil) }}
KELLNR_LOG__LEVEL: {{ .Values.kellnr.log.level | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.log.format nil) }}
KELLNR_LOG__FORMAT: {{ .Values.kellnr.log.format | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.log.levelWebServer nil) }}
KELLNR_LOG__LEVEL_WEB_SERVER: {{ .Values.kellnr.log.levelWebServer | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.local.ip nil) }}
KELLNR_LOCAL__IP: {{ .Values.kellnr.local.ip | quote }}
{{ end }}
KELLNR_LOCAL__PORT: {{ .Values.service.api.port | quote }}
KELLNR_ORIGIN__HOSTNAME: {{ required "A valid hostname, where Kellnr will be reachable is required." .Values.kellnr.origin.hostname | quote }}
{{ if .Values.ingress.path }}
KELLNR_ORIGIN__PATH: {{ .Values.ingress.path | quote }}
{{ end }}
KELLNR_ORIGIN__PORT: {{ include "kellnr.serviceOriginPort" . | quote }}
{{ if not (eq .Values.kellnr.origin.protocol nil) }}
KELLNR_ORIGIN__PROTOCOL: {{ .Values.kellnr.origin.protocol | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.postgres.enabled nil) }}
KELLNR_POSTGRESQL__ENABLED: {{ .Values.kellnr.postgres.enabled | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.postgres.address nil) }}
KELLNR_POSTGRESQL__ADDRESS: {{ .Values.kellnr.postgres.address | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.postgres.port nil) }}
KELLNR_POSTGRESQL__PORT: {{ .Values.kellnr.postgres.port | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.postgres.user nil) }}
KELLNR_POSTGRESQL__USER: {{ .Values.kellnr.postgres.user | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.postgres.db nil) }}
KELLNR_POSTGRESQL__DB: {{ .Values.kellnr.postgres.db | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.s3.enabled nil) }}
KELLNR_S3__ENABLED: {{ .Values.kellnr.s3.enabled | quote }}
{{ end }}
{{ if .Values.kellnr.s3.accessKey }}
KELLNR_S3__ACCESS_KEY: {{ .Values.kellnr.s3.accessKey | quote }}
{{ end }}
{{ if .Values.kellnr.s3.secretKey }}
KELLNR_S3__SECRET_KEY: {{ .Values.kellnr.s3.secretKey | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.s3.region nil) }}
KELLNR_S3__REGION: {{ .Values.kellnr.s3.region | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.s3.endpoint nil) }}
KELLNR_S3__ENDPOINT: {{ .Values.kellnr.s3.endpoint | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.s3.allowHttp nil) }}
KELLNR_S3__ALLOW_HTTP: {{ .Values.kellnr.s3.allowHttp | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.s3.crates_bucket nil) }}
KELLNR_S3__CRATES_BUCKET: {{ .Values.kellnr.s3.crates_bucket | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.s3.cratesio_bucket nil) }}
KELLNR_S3__CRATESIO_BUCKET: {{ .Values.kellnr.s3.cratesio_bucket | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.oauth2.enabled nil) }}
KELLNR_OAUTH2__ENABLED: {{ .Values.kellnr.oauth2.enabled | quote }}
{{ end }}
{{ if .Values.kellnr.oauth2.issuerUrl }}
KELLNR_OAUTH2__ISSUER_URL: {{ .Values.kellnr.oauth2.issuerUrl | quote }}
{{ end }}
{{ if .Values.kellnr.oauth2.clientId }}
KELLNR_OAUTH2__CLIENT_ID: {{ .Values.kellnr.oauth2.clientId | quote }}
{{ end }}
{{ if and .Values.kellnr.oauth2.clientSecret (not .Values.kellnr.oauth2.clientSecretRef.name) }}
KELLNR_OAUTH2__CLIENT_SECRET: {{ .Values.kellnr.oauth2.clientSecret | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.oauth2.scopes nil) }}
KELLNR_OAUTH2__SCOPES: {{ .Values.kellnr.oauth2.scopes | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.oauth2.autoProvisionUsers nil) }}
KELLNR_OAUTH2__AUTO_PROVISION_USERS: {{ .Values.kellnr.oauth2.autoProvisionUsers | quote }}
{{ end }}
{{ if .Values.kellnr.oauth2.adminGroupClaim }}
KELLNR_OAUTH2__ADMIN_GROUP_CLAIM: {{ .Values.kellnr.oauth2.adminGroupClaim | quote }}
{{ end }}
{{ if .Values.kellnr.oauth2.adminGroupValue }}
KELLNR_OAUTH2__ADMIN_GROUP_VALUE: {{ .Values.kellnr.oauth2.adminGroupValue | quote }}
{{ end }}
{{ if .Values.kellnr.oauth2.readOnlyGroupClaim }}
KELLNR_OAUTH2__READ_ONLY_GROUP_CLAIM: {{ .Values.kellnr.oauth2.readOnlyGroupClaim | quote }}
{{ end }}
{{ if .Values.kellnr.oauth2.readOnlyGroupValue }}
KELLNR_OAUTH2__READ_ONLY_GROUP_VALUE: {{ .Values.kellnr.oauth2.readOnlyGroupValue | quote }}
{{ end }}
{{ if not (eq .Values.kellnr.oauth2.buttonText nil) }}
KELLNR_OAUTH2__BUTTON_TEXT: {{ .Values.kellnr.oauth2.buttonText | quote }}
{{ end }}
{{- end }}

{{/*
Build the origin URL (protocol + hostname + optional port).
Omits the port when it matches the default for the protocol (443 for https, 80 for http).
*/}}
{{- define "kellnr.originUrl" -}}
{{- $protocol := default "http" .Values.kellnr.origin.protocol -}}
{{- $port := include "kellnr.serviceOriginPort" . | int -}}
{{- $defaultPort := 80 -}}
{{- if eq $protocol "https" -}}
  {{- $defaultPort = 443 -}}
{{- end -}}
{{- if eq (int $port) (int $defaultPort) -}}
{{- printf "%s://%s" $protocol .Values.kellnr.origin.hostname -}}
{{- else -}}
{{- printf "%s://%s:%d" $protocol .Values.kellnr.origin.hostname $port -}}
{{- end -}}
{{- end }}


