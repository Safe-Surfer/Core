{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "safesurfer-dns.name" -}}
{{- default "safesurfer" .Values.dns.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "safesurfer-dns.chart" -}}
{{- printf "%s-%s" "safesurfer" .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "safesurfer-dns.labels" -}}
helm.sh/chart: {{ include "safesurfer-dns.chart" . }}
{{ include "safesurfer-dns.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "safesurfer-dns.selectorLabels" -}}
app.kubernetes.io/name: {{ include "safesurfer-dns.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Shared environment variables for the filtering dns-proxy frontends
(plaindns, doh, dot, doq). They all run the policy engine against the LMDB
volume and emit the same telemetry, so the wiring lives here once.
Caller passes (dict "Values" .Values "Release" .Release).
*/}}
{{- define "dnsPolicyEnvs" }}
- name: LMDB_LOCATION
  value: '/lmdb'
{{- if .Values.dns.blockHostOverride }}
- name: BLOCK_HOST
  value: {{ .Values.dns.blockHostOverride }}
{{- else }}
- name: BLOCK_HOST
  value: {{ .Values.blockpage.domain }}
{{- end }}
{{- if .Values.blockpage.enabledForUsersByDefault }}
- name: SS_BLOCK_PAGE_ENABLED_DEFAULT
  value: '1'
{{- end }}
- name: SS_PROTO_ACTIVE_HOST
  value: {{ .Values.protocolchecker.domains.active }}.{{ .Values.protocolchecker.domains.base }}
- name: SS_PROTO_PLAIN_HOST
  value: {{ .Values.protocolchecker.domains.plain }}.{{ .Values.protocolchecker.domains.base }}
- name: SS_SERVER_ID_HOST
  value: {{ .Values.protocolchecker.domains.id }}.{{ .Values.protocolchecker.domains.base }}
- name: SS_TOKEN_MATCH_DOMAIN
  value: {{ .Values.protocolchecker.domains.tokenMatch }}.{{ .Values.protocolchecker.domains.base }}
- name: SS_DOMAIN_LOOKUP_DOMAIN
  value: {{ .Values.dns.dns.debugging.domainLookupDomain }}
- name: SS_EXPLAIN_LOOKUP_DOMAIN
  value: {{ .Values.dns.dns.debugging.explainDomain }}
- name: SS_CATEGORY_LOOKUP_DOMAIN
  value: {{ .Values.dns.dns.debugging.categoryDomain }}
- name: SS_ACCOUNT_QUERY_DOMAIN
  value: {{ .Values.dns.dns.debugging.accountQueryDomain }}
{{- if .Values.dns.dns.anonymousLogging.enabled }}
- name: SS_ANONYMOUS_LOGGING_ENABLED
  value: '1'
{{- end }}
{{- if .Values.dns.dns.anonymousLogging.fullHistoryEnabled }}
- name: SS_ANONYMOUS_LOGGING_FULL_HISTORY_ENABLED
  value: '1'
{{- end }}
{{- if .Values.dns.dns.anonymousLogging.allowOptOut }}
- name: SS_ANONYMOUS_LOGGING_OPT_OUT
  value: '1'
{{- end }}
{{- if (or .Values.dns.clickhoused.external.enabled .Values.dns.clickhoused.internal.enabled) }}
{{- if .Values.dns.clickhoused.internal.enabled }}
{{- if not .Values.dns.clickhoused.internal.frontend.udp.enabled }}
{{- fail ".dns.clickhoused.internal.frontend.udp.enabled should be true if .dns.dns.enabled is true" }}
{{- end }}
- name: SS_CLICKHOUSED_HOST
  value: {{ include "name" (dict "Release" .Release "name" "clickhoused" "nameOverride" .Values.dns.clickhoused.internal.nameOverride) }}.{{ include "ns" (dict "Values" .Values "Release" .Release "IndividualNamespace" .Values.dns.namespace) }}.svc
- name: SS_CLICKHOUSED_PORT
  value: {{ .Values.dns.clickhoused.internal.frontend.udp.svcPort | quote }}
{{- else }}
- name: SS_CLICKHOUSED_HOST
  value: {{ .Values.dns.clickhoused.external.host }}
- name: SS_CLICKHOUSED_PORT
  value: {{ .Values.dns.clickhoused.external.port | quote }}
{{- end }}
{{- end }}
{{- if (and .Values.dns.ipsetd.internal.enabled .Values.dns.ipsetd.internal.frontend.udp.enabled) }}
- name: SS_IPSETD_HOST
  value: {{ include "name" (dict "Release" .Release "name" "ipsetd" "nameOverride" .Values.dns.ipsetd.internal.nameOverride) }}.{{ include "ns" (dict "Values" .Values "Release" .Release "IndividualNamespace" .Values.dns.namespace) }}.svc
- name: SS_IPSETD_PORT
  value: {{ .Values.dns.ipsetd.internal.frontend.udp.svcPort | quote }}
{{- else if .Values.dns.ipsetd.external.enabled }}
- name: SS_IPSETD_HOST
  value: {{ required "need ipsetd host" .Values.dns.ipsetd.external.host }}
- name: SS_IPSETD_PORT
  value: {{ required "need ipsetd port" .Values.dns.ipsetd.external.port | quote }}
{{- end }}
{{- end }}

{{/*
dnscrypt pod spec
*/}}
{{- define "safesurfer-dns.dnsdist-pod" -}}
      {{- if .Values.dns.dnscrypt.hostNetwork }}
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      {{- end }}
      automountServiceAccountToken: false
      imagePullSecrets:
      - name: {{ include "name" (dict "Release" .Release "name" "dns" "nameOverride" .Values.dns.dns.nameOverride) }}-gitlab-registry
      volumes:
      - name: certs
        secret:
          secretName: {{ include "name" (dict "Release" .Release "name" "dnscrypt" "nameOverride" .Values.dns.dnscrypt.nameOverride) }}-certs
      - name: var-www-logs
        emptyDir: {}
      containers:
      - name: {{ include "dnscryptContainerAndAppName" . }}
        image: {{ .Values.dns.dnscrypt.image }}
        securityContext:
          {{- toYaml .Values.dns.dnscrypt.securityContext | nindent 12 }}
        ports:
          - name: https-udp
            containerPort: {{ .Values.dns.dnscrypt.bindPort }}
            protocol: UDP
          - name: https-tcp
            containerPort: {{ .Values.dns.dnscrypt.bindPort }}
            protocol: TCP
        volumeMounts:
        - name: var-www-logs
          mountPath: /var/www/logs
        - name: certs
          mountPath: /etc/dnsdist/certs
          readOnly: true
        env:
          - name: TZ
            valueFrom:
              configMapKeyRef:
                name: {{ include "name" (dict "Release" .Release "name" "dns" "nameOverride" .Values.dns.dns.nameOverride) }}
                key: timezone
          # If both dnscrypt and the base resolver are using host networking and the base resolver is running on port
          # 53, we can set this up without kube proxy in between.
          {{- if and (.Values.dns.dnscrypt.hostNetwork) (and (.Values.dns.dns.hostNetwork) (eq (.Values.dns.dns.bindPort | int64) (53 | int64))) }}
          - name: SS_DNS_SERVER
            value: 'localhost'
          {{- else }}
          {{- if (and .Values.testFlags .Values.testFlags.legacyNames) }}
          - name: SS_DNS_SERVER
            value: {{ include "name" (dict "Release" .Release "name" "safesurfer-internal") }}
          {{- else }}
          - name: SS_DNS_SERVER
            value: {{ include "name" (dict "Release" .Release "name" "dns-internal") }}
          {{- end }}
          {{- end }}
          - name: SS_DNSDIST_PORT
            value: {{ .Values.dns.dnscrypt.bindPort | quote }}
          - name: SS_DNSDIST_CERT_URL
            value: {{ .Values.dns.dnscrypt.cert.url }}
          - name: SS_DNSDIST_PROTO_QUERY_DOMAIN
            value: {{ .Values.dns.dns.debugging.protoQueryDomain }}
          - name: SS_DNSDIST_PROTO_QUERY_ACTIVE_DOMAIN
            value: {{ .Values.protocolchecker.domains.active }}.{{ .Values.protocolchecker.domains.base }}
          - name: SS_DNSDIST_PROTO_QUERY_DNSCRYPT_DOMAIN
            value: {{ .Values.protocolchecker.domains.dnscrypt }}.{{ .Values.protocolchecker.domains.base }}
          {{- with .Values.dns.dnscrypt.extraEnv }}
            {{- toYaml . | nindent 10 }}
          {{- end }}
          {{- with .Values.dns.extraEnv }}
            {{- toYaml . | nindent 10 }}
          {{- end }}
        readinessProbe:
          tcpSocket:
            port: {{ .Values.dns.dnscrypt.bindPort }}
          initialDelaySeconds: 2
          periodSeconds: 10
        livenessProbe:
          tcpSocket:
            port: {{ .Values.dns.dnscrypt.bindPort }}
          initialDelaySeconds: 1
          periodSeconds: 20
        resources:
          {{- toYaml .Values.dns.dnscrypt.resources | nindent 12 }}        
      {{- with .Values.dns.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.dns.dnscrypt.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.dns.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
