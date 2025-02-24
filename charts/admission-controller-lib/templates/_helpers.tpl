{{- define "admission-controller-lib.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "admission-controller-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "admission-controller-lib.env" -}}
- name: K8S_API_URL
  value: https://kubernetes.default:443
- name: K8S_AUTH_TYPE
  value: token
- name: K8S_CA_PATH
  value: {{ include "admission-controller-lib.kubeAuthMountRoot" . }}/ca.crt
- name: K8S_TOKEN_PATH
  value: {{ include "admission-controller-lib.kubeAuthMountRoot" . }}/token
- name: K8S_NS
  value: {{ .Release.Namespace | default "default" | quote }}
- name: SERVICE_NAME
  value: "{{ .Values.admissionController.serviceName }}"
- name: WEBHOOK_PATH
  value: "{{ .Values.admissionController.webhookPath }}"
- name: OBJECT_SELECTOR
  value: "{{ .Values.admissionController.objectSelector | toJson | quote }}"
- name: NAMESPACE_SELECTOR
  value: "{{ .Values.admissionController.namespaceSelector | toJson | quote }}"
- name: FAILURE_POLICY
  value: "{{ .Values.admissionController.failurePolicy }}"
{{- end -}}

{{- define "admission-controller-lib.kubeAuthMountRoot" -}}
{{- printf "/var/run/secrets/kubernetes.io/serviceaccount" -}}
{{- end -}}

{{- define "admission-controller-lib.labels.standard" -}}
app.kubernetes.io/name: {{ include "admission-controller-lib.fullname" . }}
helm.sh/chart: {{ include "admission-controller-lib.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}
