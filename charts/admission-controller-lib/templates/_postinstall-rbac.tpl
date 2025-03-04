{{- define "admission-controller-lib.postinstallRBAC" -}}

apiVersion: v1
kind: ServiceAccount
metadata:
  name: admission-controller-lib
  labels:
    {{- include "admission-controller-lib.labels.standard" . | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admission-controller-lib
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
  name: admission-controller-lib
  labels:
    {{- include "admission-controller-lib.labels.standard" . | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
subjects:
  - kind: ServiceAccount
    name: admission-controller-lib
    namespace: {{ .Release.Namespace }}
roleRef:
  kind: ClusterRole
  name: admission-controller-lib
  apiGroup: rbac.authorization.k8s.io

{{- end -}}