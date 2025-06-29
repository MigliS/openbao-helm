{{/*
Copyright (c) HashiCorp, Inc.
SPDX-License-Identifier: MPL-2.0
*/}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to
this (by the DNS naming spec). If release name contains chart name it will
be used as a full name.
*/}}
{{- define "openbao.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openbao.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "openbao.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Allow the release namespace to be overridden
*/}}
{{- define "openbao.namespace" -}}
{{- default .Release.Namespace .Values.global.namespace -}}
{{- end -}}

{{/*
Compute if the csi driver is enabled.
*/}}
{{- define "openbao.csiEnabled" -}}
{{- $_ := set . "csiEnabled" (or
  (eq (.Values.csi.enabled | toString) "true")
  (and (eq (.Values.csi.enabled | toString) "-") (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{/*
Compute if the injector is enabled.
*/}}
{{- define "openbao.injectorEnabled" -}}
{{- $_ := set . "injectorEnabled" (or
  (eq (.Values.injector.enabled | toString) "true")
  (and (eq (.Values.injector.enabled | toString) "-") (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{/*
Compute if the server is enabled.
*/}}
{{- define "openbao.serverEnabled" -}}
{{- $_ := set . "serverEnabled" (or
  (eq (.Values.server.enabled | toString) "true")
  (and (eq (.Values.server.enabled | toString) "-") (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{/*
Compute if the server serviceaccount is enabled.
*/}}
{{- define "openbao.serverServiceAccountEnabled" -}}
{{- $_ := set . "serverServiceAccountEnabled"
  (and
    (eq (.Values.server.serviceAccount.create | toString) "true" )
    (or
      (eq (.Values.server.enabled | toString) "true")
      (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{/*
Compute if the server serviceaccount should have a token created and mounted to the serviceaccount.
*/}}
{{- define "openbao.serverServiceAccountSecretCreationEnabled" -}}
{{- $_ := set . "serverServiceAccountSecretCreationEnabled"
  (and
    (eq (.Values.server.serviceAccount.create | toString) "true")
    (eq (.Values.server.serviceAccount.createSecret | toString) "true")) -}}
{{- end -}}


{{/*
Compute if the server auth delegator serviceaccount is enabled.
*/}}
{{- define "openbao.serverAuthDelegator" -}}
{{- $_ := set . "serverAuthDelegator"
  (and
    (eq (.Values.server.authDelegator.enabled | toString) "true" )
    (or (eq (.Values.server.serviceAccount.create | toString) "true")
        (not (eq .Values.server.serviceAccount.name "")))
    (or
      (eq (.Values.server.enabled | toString) "true")
      (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{/*
Compute if the server service is enabled.
*/}}
{{- define "openbao.serverServiceEnabled" -}}
{{- template "openbao.serverEnabled" . -}}
{{- $_ := set . "serverServiceEnabled" (and .serverEnabled (eq (.Values.server.service.enabled | toString) "true")) -}}
{{- end -}}

{{/*
Compute if the ui is enabled.
*/}}
{{- define "openbao.uiEnabled" -}}
{{- $_ := set . "uiEnabled" (or
  (eq (.Values.ui.enabled | toString) "true")
  (and (eq (.Values.ui.enabled | toString) "-") (eq (.Values.global.enabled | toString) "true"))) -}}
{{- end -}}

{{/*
Compute the maximum number of unavailable replicas for the PodDisruptionBudget.
This defaults to (n/2)-1 where n is the number of members of the server cluster.
Add a special case for replicas=1, where it should default to 0 as well.
*/}}
{{- define "openbao.pdb.maxUnavailable" -}}
{{- if eq (int .Values.server.ha.replicas) 1 -}}
{{ 0 }}
{{- else if .Values.server.ha.disruptionBudget.maxUnavailable -}}
{{ .Values.server.ha.disruptionBudget.maxUnavailable -}}
{{- else -}}
{{- div (sub (div (mul (int .Values.server.ha.replicas) 10) 2) 1) 10 -}}
{{- end -}}
{{- end -}}

{{/*
Resolve the external OpenBao/Vault address by checking global and injector values in order of precedence:
1. global.externalBaoAddr
2. global.externalVaultAddr 
*/}}

{{- define "openbao.externalAddr" -}}
  {{- if .Values.global.externalBaoAddr -}}
    {{- .Values.global.externalBaoAddr -}}
  {{- else -}}
    {{- .Values.global.externalVaultAddr -}}
  {{- end -}}
{{- end -}}

{{/*
Set the variable 'mode' to the server mode requested by the user to simplify
template logic.
*/}}
{{- define "openbao.mode" -}}
  {{- template "openbao.serverEnabled" . -}}
  {{- if or (.Values.injector.externalVaultAddr) (.Values.global.externalVaultAddr) (.Values.global.externalBaoAddr) -}}
    {{- $_ := set . "mode" "external" -}}
  {{- else if not .serverEnabled -}}
    {{- $_ := set . "mode" "external" -}}
  {{- else if eq (.Values.server.dev.enabled | toString) "true" -}}
    {{- $_ := set . "mode" "dev" -}}
  {{- else if eq (.Values.server.ha.enabled | toString) "true" -}}
    {{- $_ := set . "mode" "ha" -}}
  {{- else if or (eq (.Values.server.standalone.enabled | toString) "true") (eq (.Values.server.standalone.enabled | toString) "-") -}}
    {{- $_ := set . "mode" "standalone" -}}
  {{- else -}}
    {{- $_ := set . "mode" "" -}}
  {{- end -}}
{{- end -}}

{{/*
Set's the replica count based on the different modes configured by user
*/}}
{{- define "openbao.replicas" -}}
  {{ if eq .mode "standalone" }}
    {{- default 1 -}}
  {{ else if eq .mode "ha" }}
    {{- if or (kindIs "int64" .Values.server.ha.replicas) (kindIs "float64" .Values.server.ha.replicas) -}}
      {{- .Values.server.ha.replicas -}}
    {{ else }}
      {{- 3 -}}
    {{- end -}}
  {{ else }}
    {{- default 1 -}}
  {{ end }}
{{- end -}}

{{/*
Set's up configmap mounts if this isn't a dev deployment and the user
defined a custom configuration.  Additionally iterates over any
extra volumes the user may have specified (such as a secret with TLS).
*/}}
{{- define "openbao.volumes" -}}
  {{- if and (ne .mode "dev") (or (.Values.server.standalone.config) (.Values.server.ha.config)) }}
        - name: config
          configMap:
            name: {{ template "openbao.fullname" . }}-config
  {{ end }}
  {{- range .Values.server.extraVolumes }}
        - name: userconfig-{{ .name }}
          {{ .type }}:
          {{- if (eq .type "configMap") }}
            name: {{ .name }}
          {{- else if (eq .type "secret") }}
            secretName: {{ .name }}
          {{- end }}
            defaultMode: {{ .defaultMode | default 420 }}
  {{- end }}
  {{- if .Values.server.volumes }}
    {{- toYaml .Values.server.volumes | nindent 8}}
  {{- end }}
{{- end -}}

{{/*
Set's the args for custom command to render the OpenBao configuration
file with IP addresses to make the out of box experience easier
for users looking to use this chart with Consul Helm.
*/}}
{{- define "openbao.args" -}}
  {{ if or (eq .mode "standalone") (eq .mode "ha") }}
          - |
            cp /openbao/config/extraconfig-from-values.hcl /tmp/storageconfig.hcl;
            [ -n "${HOST_IP}" ] && sed -Ei "s|HOST_IP|${HOST_IP?}|g" /tmp/storageconfig.hcl;
            [ -n "${POD_IP}" ] && sed -Ei "s|POD_IP|${POD_IP?}|g" /tmp/storageconfig.hcl;
            [ -n "${HOSTNAME}" ] && sed -Ei "s|HOSTNAME|${HOSTNAME?}|g" /tmp/storageconfig.hcl;
            [ -n "${API_ADDR}" ] && sed -Ei "s|API_ADDR|${API_ADDR?}|g" /tmp/storageconfig.hcl;
            [ -n "${TRANSIT_ADDR}" ] && sed -Ei "s|TRANSIT_ADDR|${TRANSIT_ADDR?}|g" /tmp/storageconfig.hcl;
            [ -n "${RAFT_ADDR}" ] && sed -Ei "s|RAFT_ADDR|${RAFT_ADDR?}|g" /tmp/storageconfig.hcl;
            /usr/local/bin/docker-entrypoint.sh bao server -config=/tmp/storageconfig.hcl {{ .Values.server.extraArgs }}
   {{ else if eq .mode "dev" }}
          - |
            /usr/local/bin/docker-entrypoint.sh bao server -dev {{ .Values.server.extraArgs }}
  {{ end }}
{{- end -}}

{{/*
Set's additional environment variables based on the mode.
*/}}
{{- define "openbao.envs" -}}
  {{ if eq .mode "dev" }}
            - name: VAULT_DEV_ROOT_TOKEN_ID
              value: {{ .Values.server.dev.devRootToken }}
            - name: VAULT_DEV_LISTEN_ADDRESS
              value: "[::]:8200"
  {{ end }}
{{- end -}}

{{/*
Set's which additional volumes should be mounted to the container
based on the mode configured.
*/}}
{{- define "openbao.mounts" -}}
  {{ if eq (.Values.server.auditStorage.enabled | toString) "true" }}
            - name: audit
              mountPath: {{ .Values.server.auditStorage.mountPath }}
  {{ end }}
  {{ if or (eq .mode "standalone") (and (eq .mode "ha") (eq (.Values.server.ha.raft.enabled | toString) "true"))  }}
    {{ if eq (.Values.server.dataStorage.enabled | toString) "true" }}
            - name: data
              mountPath: {{ .Values.server.dataStorage.mountPath }}
    {{ end }}
  {{ end }}
  {{ if and (ne .mode "dev") (or (.Values.server.standalone.config)  (.Values.server.ha.config)) }}
            - name: config
              mountPath: /openbao/config
  {{ end }}
  {{- range .Values.server.extraVolumes }}
            - name: userconfig-{{ .name }}
              readOnly: true
              mountPath: {{ .path | default "/openbao/userconfig" }}/{{ .name }}
  {{- end }}
  {{- if .Values.server.volumeMounts }}
    {{- toYaml .Values.server.volumeMounts | nindent 12}}
  {{- end }}
{{- end -}}

{{/*
Set's up the volumeClaimTemplates when data or audit storage is required.  HA
might not use data storage since Consul is likely it's backend, however, audit
storage might be desired by the user.
*/}}
{{- define "openbao.volumeclaims" -}}
  {{- if and (ne .mode "dev") (or .Values.server.dataStorage.enabled .Values.server.auditStorage.enabled) }}
  volumeClaimTemplates:
      {{- if and (eq (.Values.server.dataStorage.enabled | toString) "true") (or (eq .mode "standalone") (eq (.Values.server.ha.raft.enabled | toString ) "true" )) }}
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: data
        {{- include "openbao.dataVolumeClaim.annotations" . | nindent 6 }}
        {{- include "openbao.dataVolumeClaim.labels" . | nindent 6 }}
      spec:
        accessModes:
          - {{ .Values.server.dataStorage.accessMode | default "ReadWriteOnce" }}
        resources:
          requests:
            storage: {{ .Values.server.dataStorage.size }}
          {{- if .Values.server.dataStorage.storageClass }}
        storageClassName: {{ .Values.server.dataStorage.storageClass }}
          {{- end }}
      {{ end }}
      {{- if eq (.Values.server.auditStorage.enabled | toString) "true" }}
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: audit
        {{- include "openbao.auditVolumeClaim.annotations" . | nindent 6 }}
        {{- include "openbao.auditVolumeClaim.labels" . | nindent 6 }}
      spec:
        accessModes:
          - {{ .Values.server.auditStorage.accessMode | default "ReadWriteOnce" }}
        resources:
          requests:
            storage: {{ .Values.server.auditStorage.size }}
          {{- if .Values.server.auditStorage.storageClass }}
        storageClassName: {{ .Values.server.auditStorage.storageClass }}
          {{- end }}
      {{ end }}
  {{ end }}
{{- end -}}

{{/*
Set's the affinity for pod placement when running in standalone and HA modes.
*/}}
{{- define "openbao.affinity" -}}
  {{- if and (ne .mode "dev") .Values.server.affinity }}
      affinity:
        {{ $tp := typeOf .Values.server.affinity }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.server.affinity . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.server.affinity | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{/*
Sets the injector affinity for pod placement
*/}}
{{- define "injector.affinity" -}}
  {{- if .Values.injector.affinity }}
      affinity:
        {{ $tp := typeOf .Values.injector.affinity }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.injector.affinity . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.injector.affinity | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{/*
Sets the topologySpreadConstraints when running in standalone and HA modes.
*/}}
{{- define "openbao.topologySpreadConstraints" -}}
  {{- if and (ne .mode "dev") .Values.server.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{ $tp := typeOf .Values.server.topologySpreadConstraints }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.server.topologySpreadConstraints . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.server.topologySpreadConstraints | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}


{{/*
Sets the injector topologySpreadConstraints for pod placement
*/}}
{{- define "injector.topologySpreadConstraints" -}}
  {{- if .Values.injector.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{ $tp := typeOf .Values.injector.topologySpreadConstraints }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.injector.topologySpreadConstraints . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.injector.topologySpreadConstraints | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}

{{/*
Sets the toleration for pod placement when running in standalone and HA modes.
*/}}
{{- define "openbao.tolerations" -}}
  {{- if and (ne .mode "dev") .Values.server.tolerations }}
      tolerations:
      {{- $tp := typeOf .Values.server.tolerations }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.server.tolerations . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.server.tolerations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets the injector toleration for pod placement
*/}}
{{- define "injector.tolerations" -}}
  {{- if .Values.injector.tolerations }}
      tolerations:
      {{- $tp := typeOf .Values.injector.tolerations }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.injector.tolerations . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.injector.tolerations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Set's the node selector for pod placement when running in standalone and HA modes.
*/}}
{{- define "openbao.nodeselector" -}}
  {{- if and (ne .mode "dev") .Values.server.nodeSelector }}
      nodeSelector:
      {{- $tp := typeOf .Values.server.nodeSelector }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.server.nodeSelector . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.server.nodeSelector | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets the injector node selector for pod placement
*/}}
{{- define "injector.nodeselector" -}}
  {{- if .Values.injector.nodeSelector }}
      nodeSelector:
      {{- $tp := typeOf .Values.injector.nodeSelector }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.injector.nodeSelector . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.injector.nodeSelector | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets the injector deployment update strategy
*/}}
{{- define "injector.strategy" -}}
  {{- if .Values.injector.strategy }}
  strategy:
  {{- $tp := typeOf .Values.injector.strategy }}
  {{- if eq $tp "string" }}
    {{ tpl .Values.injector.strategy . | nindent 4 | trim }}
  {{- else }}
    {{- toYaml .Values.injector.strategy | nindent 4 }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra pod annotations
*/}}
{{- define "openbao.annotations" }}
      annotations:
  {{- if .Values.server.configAnnotation }}
        openbao.hashicorp.com/config-checksum: {{ include "openbao.config" . | sha256sum }}
  {{- end }}
  {{- if .Values.server.annotations }}
        {{- $tp := typeOf .Values.server.annotations }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.server.annotations . | nindent 8 }}
        {{- else }}
          {{- toYaml .Values.server.annotations | nindent 8 }}
        {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra injector pod annotations
*/}}
{{- define "injector.annotations" -}}
  {{- if .Values.injector.annotations }}
      annotations:
        {{- $tp := typeOf .Values.injector.annotations }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.injector.annotations . | nindent 8 }}
        {{- else }}
          {{- toYaml .Values.injector.annotations | nindent 8 }}
        {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra injector service annotations
*/}}
{{- define "injector.service.annotations" -}}
  {{- if .Values.injector.service.annotations }}
  annotations:
    {{- $tp := typeOf .Values.injector.service.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.injector.service.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.injector.service.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
securityContext for the injector pod level.
*/}}
{{- define "injector.securityContext.pod" -}}
  {{- if .Values.injector.securityContext.pod }}
      securityContext:
        {{- $tp := typeOf .Values.injector.securityContext.pod }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.injector.securityContext.pod . | nindent 8 }}
        {{- else }}
          {{- toYaml .Values.injector.securityContext.pod | nindent 8 }}
        {{- end }}
  {{- else if not .Values.global.openshift }}
      securityContext:
        runAsNonRoot: true
        runAsGroup: {{ .Values.injector.gid | default 1000 }}
        runAsUser: {{ .Values.injector.uid | default 100 }}
        fsGroup: {{ .Values.injector.gid | default 1000 }}
  {{- end }}
{{- end -}}

{{/*
securityContext for the injector container level.
*/}}
{{- define "injector.securityContext.container" -}}
  {{- if .Values.injector.securityContext.container}}
          securityContext:
            {{- $tp := typeOf .Values.injector.securityContext.container }}
            {{- if eq $tp "string" }}
              {{- tpl .Values.injector.securityContext.container . | nindent 12 }}
            {{- else }}
              {{- toYaml .Values.injector.securityContext.container | nindent 12 }}
            {{- end }}
  {{- else if not .Values.global.openshift }}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
  {{- end }}
{{- end -}}

{{/*
securityContext for the statefulset pod template.
*/}}
{{- define "server.statefulSet.securityContext.pod" -}}
  {{- if .Values.server.statefulSet.securityContext.pod }}
      securityContext:
        {{- $tp := typeOf .Values.server.statefulSet.securityContext.pod }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.server.statefulSet.securityContext.pod . | nindent 8 }}
        {{- else }}
          {{- toYaml .Values.server.statefulSet.securityContext.pod | nindent 8 }}
        {{- end }}
  {{- else if not .Values.global.openshift }}
      securityContext:
        runAsNonRoot: true
        runAsGroup: {{ .Values.server.gid | default 1000 }}
        runAsUser: {{ .Values.server.uid | default 100 }}
        fsGroup: {{ .Values.server.gid | default 1000 }}
  {{- end }}
{{- end -}}

{{/*
securityContext for the statefulset openbao container
*/}}
{{- define "server.statefulSet.securityContext.container" -}}
  {{- if .Values.server.statefulSet.securityContext.container }}
          securityContext:
            {{- $tp := typeOf .Values.server.statefulSet.securityContext.container }}
            {{- if eq $tp "string" }}
              {{- tpl .Values.server.statefulSet.securityContext.container . | nindent 12 }}
            {{- else }}
              {{- toYaml .Values.server.statefulSet.securityContext.container | nindent 12 }}
            {{- end }}
  {{- else if not .Values.global.openshift }}
          securityContext:
            allowPrivilegeEscalation: false
  {{- end }}
{{- end -}}


{{/*
Sets extra injector service account annotations
*/}}
{{- define "injector.serviceAccount.annotations" -}}
  {{- if and (ne .mode "dev") .Values.injector.serviceAccount.annotations }}
  annotations:
    {{- $tp := typeOf .Values.injector.serviceAccount.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.injector.serviceAccount.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.injector.serviceAccount.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra injector webhook annotations
*/}}
{{- define "injector.webhookAnnotations" -}}
  {{- if or (((.Values.injector.webhook)).annotations) (.Values.injector.webhookAnnotations)  }}
  annotations:
    {{- $tp := typeOf (or (((.Values.injector.webhook)).annotations) (.Values.injector.webhookAnnotations)) }}
    {{- if eq $tp "string" }}
      {{- tpl (((.Values.injector.webhook)).annotations | default .Values.injector.webhookAnnotations) . | nindent 4 }}
    {{- else }}
      {{- toYaml (((.Values.injector.webhook)).annotations | default .Values.injector.webhookAnnotations) | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Set's the injector webhook objectSelector
*/}}
{{- define "injector.objectSelector" -}}
  {{- $v := or (((.Values.injector.webhook)).objectSelector) (.Values.injector.objectSelector) -}}
  {{ if $v }}
    objectSelector:
    {{- $tp := typeOf $v -}}
    {{ if eq $tp "string" }}
      {{ tpl $v . | indent 6 | trim }}
    {{ else }}
      {{ toYaml $v | indent 6 | trim }}
    {{ end }}
  {{ end }}
{{ end }}

{{/*
Sets extra ui service annotations
*/}}
{{- define "openbao.ui.annotations" -}}
  {{- if .Values.ui.annotations }}
  annotations:
    {{- $tp := typeOf .Values.ui.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.ui.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.ui.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "openbao.serviceAccount.name" -}}
{{- if .Values.server.serviceAccount.create -}}
    {{ default (include "openbao.fullname" .) .Values.server.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.server.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Sets extra service account annotations
*/}}
{{- define "openbao.serviceAccount.annotations" -}}
  {{- if and (ne .mode "dev") .Values.server.serviceAccount.annotations }}
  annotations:
    {{- $tp := typeOf .Values.server.serviceAccount.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.serviceAccount.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.serviceAccount.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra ingress annotations
*/}}
{{- define "openbao.ingress.annotations" -}}
  {{- if .Values.server.ingress.annotations }}
  annotations:
    {{- $tp := typeOf .Values.server.ingress.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.ingress.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.ingress.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra route annotations
*/}}
{{- define "openbao.route.annotations" -}}
  {{- if .Values.server.route.annotations }}
  annotations:
    {{- $tp := typeOf .Values.server.route.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.route.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.route.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra openbao server Service annotations
*/}}
{{- define "openbao.service.annotations" -}}
  {{- if .Values.server.service.annotations }}
    {{- $tp := typeOf .Values.server.service.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.service.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.service.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra openbao server Service (active) annotations
*/}}
{{- define "openbao.service.active.annotations" -}}
  {{- if .Values.server.service.active.annotations }}
    {{- $tp := typeOf .Values.server.service.active.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.service.active.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.service.active.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}
{{/*
Sets extra openbao server Service annotations
*/}}
{{- define "openbao.service.standby.annotations" -}}
  {{- if .Values.server.service.standby.annotations }}
    {{- $tp := typeOf .Values.server.service.standby.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.service.standby.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.service.standby.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets PodSecurityPolicy annotations
*/}}
{{- define "openbao.psp.annotations" -}}
  {{- if .Values.global.psp.annotations }}
  annotations:
    {{- $tp := typeOf .Values.global.psp.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.global.psp.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.global.psp.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra statefulset annotations
*/}}
{{- define "openbao.statefulSet.annotations" -}}
  {{- if .Values.server.statefulSet.annotations }}
  annotations:
    {{- $tp := typeOf .Values.server.statefulSet.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.statefulSet.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.statefulSet.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets VolumeClaim annotations for data volume
*/}}
{{- define "openbao.dataVolumeClaim.annotations" -}}
  {{- if and (ne .mode "dev") (.Values.server.dataStorage.enabled) (.Values.server.dataStorage.annotations) }}
  annotations:
    {{- $tp := typeOf .Values.server.dataStorage.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.dataStorage.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.dataStorage.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets VolumeClaim labels for data volume
*/}}
{{- define "openbao.dataVolumeClaim.labels" -}}
  {{- if and (ne .mode "dev") (.Values.server.dataStorage.enabled) (.Values.server.dataStorage.labels) }}
  labels:
    {{- $tp := typeOf .Values.server.dataStorage.labels }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.dataStorage.labels . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.dataStorage.labels | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets VolumeClaim annotations for audit volume
*/}}
{{- define "openbao.auditVolumeClaim.annotations" -}}
  {{- if and (ne .mode "dev") (.Values.server.auditStorage.enabled) (.Values.server.auditStorage.annotations) }}
  annotations:
    {{- $tp := typeOf .Values.server.auditStorage.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.auditStorage.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.auditStorage.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets VolumeClaim labels for audit volume
*/}}
{{- define "openbao.auditVolumeClaim.labels" -}}
  {{- if and (ne .mode "dev") (.Values.server.auditStorage.enabled) (.Values.server.auditStorage.labels) }}
  labels:
    {{- $tp := typeOf .Values.server.auditStorage.labels }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.server.auditStorage.labels . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.server.auditStorage.labels | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Set's the container resources if the user has set any.
*/}}
{{- define "openbao.resources" -}}
  {{- if .Values.server.resources -}}
          resources:
{{ toYaml .Values.server.resources | indent 12}}
  {{ end }}
{{- end -}}

{{/*
Sets the container resources if the user has set any.
*/}}
{{- define "injector.resources" -}}
  {{- if .Values.injector.resources -}}
          resources:
{{ toYaml .Values.injector.resources | indent 12}}
  {{ end }}
{{- end -}}

{{/*
Sets the container resources if the user has set any.
*/}}
{{- define "csi.resources" -}}
  {{- if .Values.csi.resources -}}
          resources:
{{ toYaml .Values.csi.resources | indent 12}}
  {{ end }}
{{- end -}}

{{/*
Sets the container resources for CSI's Agent sidecar if the user has set any.
*/}}
{{- define "csi.agent.resources" -}}
  {{- if .Values.csi.agent.resources -}}
          resources:
{{ toYaml .Values.csi.agent.resources | indent 12}}
  {{ end }}
{{- end -}}

{{/*
Sets extra CSI daemonset annotations
*/}}
{{- define "csi.daemonSet.annotations" -}}
  {{- if .Values.csi.daemonSet.annotations }}
  annotations:
    {{- $tp := typeOf .Values.csi.daemonSet.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.csi.daemonSet.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.csi.daemonSet.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets CSI daemonset securityContext for pod template
*/}}
{{- define "csi.daemonSet.securityContext.pod" -}}
  {{- if .Values.csi.daemonSet.securityContext.pod }}
      securityContext:
    {{- $tp := typeOf .Values.csi.daemonSet.securityContext.pod }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.csi.daemonSet.securityContext.pod . | nindent 8 }}
    {{- else }}
      {{- toYaml .Values.csi.daemonSet.securityContext.pod | nindent 8 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets CSI daemonset securityContext for container
*/}}
{{- define "csi.daemonSet.securityContext.container" -}}
  {{- if .Values.csi.daemonSet.securityContext.container }}
          securityContext:
    {{- $tp := typeOf .Values.csi.daemonSet.securityContext.container }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.csi.daemonSet.securityContext.container . | nindent 12 }}
    {{- else }}
      {{- toYaml .Values.csi.daemonSet.securityContext.container | nindent 12 }}
    {{- end }}
  {{- end }}
{{- end -}}


{{/*
Sets the injector toleration for pod placement
*/}}
{{- define "csi.pod.tolerations" -}}
  {{- if .Values.csi.pod.tolerations }}
      tolerations:
      {{- $tp := typeOf .Values.csi.pod.tolerations }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.csi.pod.tolerations . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.csi.pod.tolerations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets the CSI provider nodeSelector for pod placement
*/}}
{{- define "csi.pod.nodeselector" -}}
  {{- if .Values.csi.pod.nodeSelector }}
      nodeSelector:
      {{- $tp := typeOf .Values.csi.pod.nodeSelector }}
      {{- if eq $tp "string" }}
        {{ tpl .Values.csi.pod.nodeSelector . | nindent 8 | trim }}
      {{- else }}
        {{- toYaml .Values.csi.pod.nodeSelector | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}
{{/*
Sets the CSI provider affinity for pod placement.
*/}}
{{- define "csi.pod.affinity" -}}
  {{- if .Values.csi.pod.affinity }}
      affinity:
        {{ $tp := typeOf .Values.csi.pod.affinity }}
        {{- if eq $tp "string" }}
          {{- tpl .Values.csi.pod.affinity . | nindent 8 | trim }}
        {{- else }}
          {{- toYaml .Values.csi.pod.affinity | nindent 8 }}
        {{- end }}
  {{ end }}
{{- end -}}
{{/*
Sets extra CSI provider pod annotations
*/}}
{{- define "csi.pod.annotations" -}}
  {{- if .Values.csi.pod.annotations }}
      annotations:
      {{- $tp := typeOf .Values.csi.pod.annotations }}
      {{- if eq $tp "string" }}
        {{- tpl .Values.csi.pod.annotations . | nindent 8 }}
      {{- else }}
        {{- toYaml .Values.csi.pod.annotations | nindent 8 }}
      {{- end }}
  {{- end }}
{{- end -}}

{{/*
Sets extra CSI service account annotations
*/}}
{{- define "csi.serviceAccount.annotations" -}}
  {{- if .Values.csi.serviceAccount.annotations }}
  annotations:
    {{- $tp := typeOf .Values.csi.serviceAccount.annotations }}
    {{- if eq $tp "string" }}
      {{- tpl .Values.csi.serviceAccount.annotations . | nindent 4 }}
    {{- else }}
      {{- toYaml .Values.csi.serviceAccount.annotations | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Inject extra environment vars in the format key:value, if populated
*/}}
{{- define "openbao.extraEnvironmentVars" -}}
{{- if .extraEnvironmentVars -}}
{{- range $key, $value := .extraEnvironmentVars }}
- name: {{ printf "%s" $key | replace "." "_" | upper | quote }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Inject extra environment populated by secrets, if populated
*/}}
{{- define "openbao.extraSecretEnvironmentVars" -}}
{{- if .extraSecretEnvironmentVars -}}
{{- range .extraSecretEnvironmentVars }}
- name: {{ .envName }}
  valueFrom:
   secretKeyRef:
     name: {{ .secretName }}
     key: {{ .secretKey }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Scheme for health check and local endpoint */}}
{{- define "openbao.scheme" -}}
{{- if .Values.global.tlsDisable -}}
{{ "http" }}
{{- else -}}
{{ "https" }}
{{- end -}}
{{- end -}}

{{/*
imagePullSecrets generates pull secrets from either string or map values.
A map value must be indexable by the key 'name'.
*/}}
{{- define "imagePullSecrets" -}}
{{- with .Values.global.imagePullSecrets -}}
imagePullSecrets:
{{- range . -}}
{{- if typeIs "string" . }}
  - name: {{ . }}
{{- else if index . "name" }}
  - name: {{ .name }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
externalTrafficPolicy sets a Service's externalTrafficPolicy if applicable.
Supported inputs are Values.server.service and Values.ui
*/}}
{{- define "service.externalTrafficPolicy" -}}
{{- $type := "" -}}
{{- if .serviceType -}}
{{- $type = .serviceType -}}
{{- else if .type -}}
{{- $type = .type -}}
{{- end -}}
{{- if and .externalTrafficPolicy (or (eq $type "LoadBalancer") (eq $type "NodePort")) }}
  externalTrafficPolicy: {{ .externalTrafficPolicy }}
{{- else }}
{{- end }}
{{- end -}}

{{/*
loadBalancer configuration for the the UI service.
Supported inputs are Values.ui
*/}}
{{- define "service.loadBalancer" -}}
{{- if  eq (.serviceType | toString) "LoadBalancer" }}
{{- if .loadBalancerIP }}
  loadBalancerIP: {{ .loadBalancerIP }}
{{- end }}
{{- with .loadBalancerSourceRanges }}
  loadBalancerSourceRanges:
{{- range . }}
  - {{ . }}
{{- end }}
{{- end -}}
{{- end }}
{{- end -}}

{{/*
config file from values
*/}}
{{- define "openbao.config" -}}
  {{- if or (eq .mode "ha") (eq .mode "standalone") }}
  {{- $type := typeOf (index .Values.server .mode).config }}
  {{- if eq $type "string" }}
  {{- if eq .mode "standalone" }}
    {{ tpl .Values.server.standalone.config . | nindent 4 | trim }}
  {{- else if and (eq .mode "ha") (eq (.Values.server.ha.raft.enabled | toString) "false") }}
    {{ tpl .Values.server.ha.config . | nindent 4 | trim }}
  {{- else if and (eq .mode "ha") (eq (.Values.server.ha.raft.enabled | toString) "true") }}
    {{ tpl .Values.server.ha.raft.config . | nindent 4 | trim }}
  {{ end }}
  {{- else }}
  {{- if and (eq .mode "ha") (eq (.Values.server.ha.raft.enabled | toString) "true") }}
{{ (index .Values.server .mode).raft.config | toPrettyJson | indent 4 }}
  {{- else }}
{{ (index .Values.server .mode).config | toPrettyJson | indent 4 }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}
