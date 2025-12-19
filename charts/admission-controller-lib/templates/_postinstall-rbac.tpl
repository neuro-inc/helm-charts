{{- define "admission-controller-lib.postinstallRBAC" -}}

apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "admission-controller-lib.postinstall.fullname" . }}
  labels:
    {{- include "admission-controller-lib.labels.standard" . | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ include "admission-controller-lib.postinstall.fullname" . }}
  labels:
    {{- include "admission-controller-lib.labels.standard" . | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
rules:
  - apiGroups: ["admissionregistration.k8s.io"]
    resources:
      - mutatingwebhookconfigurations
      - validatingwebhookconfigurations
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch

  - apiGroups: [""]
    resources:
      - secrets
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ include "admission-controller-lib.postinstall.fullname" . }}
  labels:
    {{- include "admission-controller-lib.labels.standard" . | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
subjects:
  - kind: ServiceAccount
    name: {{ include "admission-controller-lib.postinstall.fullname" . }}
    namespace: {{ .Release.Namespace }}
roleRef:
  kind: ClusterRole
  name: {{ include "admission-controller-lib.postinstall.fullname" . }}
  apiGroup: rbac.authorization.k8s.io

{{- end -}}
