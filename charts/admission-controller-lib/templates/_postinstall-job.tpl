{{- define "admission-controller-lib.postinstallJob" -}}

{{ include "admission-controller-lib.preinstallJob" . }}

---

apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ include "admission-controller-lib.fullname" . }}-postinstall"
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      serviceAccountName: admission-controller-lib
      restartPolicy: Never
      containers:
        - name: postinstall
          image: ghcr.io/neuro-inc/admission-controller-lib:latest
          imagePullPolicy: Always
          args: ["post-install"]
          env:
            {{- include "admission-controller-lib.env" . | nindent 12 }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}