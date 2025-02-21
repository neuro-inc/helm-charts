{{- define "admission-controller-lib.postinstallJob" -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ include "admission-controller-lib.fullname" . }}-postinstall"
  namespace: "{{ .Release.Namespace }}"
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      serviceAccountName: admission-controller-lib
      restartPolicy: Never
      containers:
        - name: postinstall
          image: ghcr.io/neuro-inc/admission-controller-lib:latest
          imagePullPolicy: IfNotPresent
          args: ["post-install"]
          env:
            {{- include "admission-controller-lib.env" . | nindent 12 }}
{{- end -}}