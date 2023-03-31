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
