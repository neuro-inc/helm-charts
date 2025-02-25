{{- define "admission-controller-lib.preinstallJob" -}}

{{ include "admission-controller-lib.rbac" . }}

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