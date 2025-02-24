{{- define "admission-controller-lib.preinstallJob" -}}

apiVersion: v1
kind: ServiceAccount
metadata:
  name: admission-controller-lib
  labels:
    {{- include "admission-controller-lib.labels.standard" . | nindent 4 }}

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admission-controller-lib
  labels:
    {{- include "admission-controller-lib.labels.standard" . | nindent 4 }}
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
subjects:
  - kind: ServiceAccount
    name: admission-controller-lib
    namespace: {{ .Release.Namespace }}
roleRef:
  kind: ClusterRole
  name: admission-controller-lib
  apiGroup: rbac.authorization.k8s.io

---

apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ include "admission-controller-lib.fullname" . }}-preinstall"
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      serviceAccountName: admission-controller-lib
      restartPolicy: Never
      containers:
        - name: preinstall
          image: ghcr.io/neuro-inc/admission-controller-lib:latest
          imagePullPolicy: Always
          args: ["pre-install"]
          env:
            {{- include "admission-controller-lib.env" . | nindent 12 }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}