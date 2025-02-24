A helm chart for an admission controller integration
---

It defines two jobs which should be included into a deployment of your webhook.

The pre-install job generates TLS certificates and a certificate authority, 
and puts them into a kube secret.

The post-install job uses those secrets and creates an admission controller with the provided values


Configuration
=============

Helm charts expects next values to be set:

```yaml

admissionController:
  serviceName: "a service name"
  webhookPath: "a webhook HTTP path which will be called by an admission controller"
  namespaceSelector: "namespace selector object in a format accepted by an admission controller"
  objectSelector: "object selector object in a format accepted by an admission controller"
  failurePolicy: "one of `Ignore` or `Fail`"

```

Development
===

Both jobs are using the docker image: `ghcr.io/neuro-inc/admission-controller-lib:latest`,
which is build from the `admission-controller-lib/src` python code.

Currently, an image uploading is not automated,
so if you do any changes to the underlying python code, 
you will need to upload an image to a registry, e.g.:

```shell
cd /path/to/helm-charts/charts/admission-controller-lib/src
docker build \
  -f Dockerfile \
  -t ghcr.io/neuro-inc/admission-controller-lib:latest \
  -t admission-controller-lib:latest \
  .
export CR_PAT=<your-gh-token>
echo $CR_PAT | docker login ghcr.io -u <gh-username> --password-stdin
docker push ghcr.io/neuro-inc/admission-controller-lib:latest
```
