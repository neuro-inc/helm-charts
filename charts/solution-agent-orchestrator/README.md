# Solution Agent Orchestrator Helm Chart

A comprehensive Helm chart for deploying the Solution Agent Orchestrator Python application to Kubernetes with all the necessary resources and configurations.

## Features

- **Deployment** with configurable replicas and update strategies
- **Service** for internal and external access
- **Ingress** support for external routing
- **Secrets** management for sensitive data
- **Environment Variables** - easy configuration for development
- **Volumes** support (ConfigMap, Secret, PVC, EmptyDir)
- **Resource Limits** and requests
- **Health Checks** (liveness, readiness, startup probes)
- **Image Tag Deployment** - specify which image tag to deploy

## Quick Start

### Installation from Public Helm Repository

The chart is available in the Helm repository. The chart name is `solution-agent-orchestrator`.

To install from the public repository:

```bash
# Add the Helm repository
helm repo add solution-agent-orchestrator https://neuro-inc.github.io/helm-charts

# Update the repository
helm repo update

# Install the chart (chart name: solution-agent-orchestrator)
helm install <release-name> solution-agent-orchestrator/solution-agent-orchestrator \
  --set image.repository=ghcr.io/your-org/solution-agent-orchestrator \
  --set image.tag=v1.2.3 \
  --set imagePullSecrets[0].name=ghcr-secret
```

**Chart Name:** `solution-agent-orchestrator`

### Installation from Local Chart

Alternatively, you can install from a local chart directory:

```bash
helm install solution-agent-orchestrator ./solution-agent-orchestrator \
  --set image.repository=ghcr.io/your-org/solution-agent-orchestrator \
  --set image.tag=v1.2.3 \
  --set imagePullSecrets[0].name=ghcr-secret
```

### Prerequisites: GitHub Container Registry Authentication

Since the image is stored in GitHub Container Registry (GHCR), you need to create an image pull secret first:

```bash
# Create a GitHub Personal Access Token (PAT) with read:packages permission
# Then create the secret:
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USERNAME> \
  --docker-password=<GITHUB_TOKEN> \
  --docker-email=<EMAIL> \
  --namespace=<your-namespace>
```

### Deploy with Specific Tag

The chart allows you to easily specify which image tag to deploy:

**Using the public Helm repository:**

```bash
# Deploy a specific version
helm install solution-agent-orchestrator solution-agent-orchestrator/solution-agent-orchestrator \
  --set image.repository=ghcr.io/your-org/solution-agent-orchestrator \
  --set image.tag=v1.2.3 \
  --set imagePullSecrets[0].name=ghcr-secret

# Or upgrade to a new tag
helm upgrade solution-agent-orchestrator solution-agent-orchestrator/solution-agent-orchestrator \
  --set image.tag=v1.2.4
```

**Using a local chart:**

```bash
# Deploy a specific version
helm install solution-agent-orchestrator ./solution-agent-orchestrator \
  --set image.repository=ghcr.io/your-org/solution-agent-orchestrator \
  --set image.tag=v1.2.3 \
  --set imagePullSecrets[0].name=ghcr-secret

# Or upgrade to a new tag
helm upgrade solution-agent-orchestrator ./solution-agent-orchestrator \
  --set image.tag=v1.2.4
```

### Required Environment Variables

The following environment variables are **REQUIRED** and must be set for the application to work:

- `API_JWT_SECRET` - Secret key for JWT token generation
- `SWAGGER_USERNAME` - Username for Swagger UI authentication
- `SWAGGER_PASSWORD` - Password for Swagger UI authentication
- `UPWORK_CLIENT_ID` - Upwork API client ID
- `UPWORK_CLIENT_SECRET` - Upwork API client secret
- `UPWORK_USER_AGENT` - User agent string for Upwork API requests
- `WEBHOOK_SECRET` - Secret for webhook validation
- `DATABASE_URL` - PostgreSQL database connection string

### Optional Environment Variables

The following environment variables are **OPTIONAL** and have defaults if not provided:

- `WEBHOOK_PREVIOUS_SECRET` - Previous webhook secret (for rotation)
- `WEBHOOK_MAX_AGE_SECONDS` - Maximum age for webhook validation (default: `120`)
- `API_PREFIX` - API route prefix (default: `/api/v1`)
- `UPWORK_OAUTH_TOKEN_URL` - Upwork OAuth token endpoint URL
- `UPWORK_API_BASE_URL` - Upwork API base URL

### Adding Environment Variables

You can add environment variables in two ways:

#### 1. Direct Environment Variables (in values.yaml or via --set)

```yaml
env:
  # Required variables
  - name: API_JWT_SECRET
    value: "your-jwt-secret-here"
  - name: SWAGGER_USERNAME
    value: "admin"
  - name: SWAGGER_PASSWORD
    value: "secure-password"
  - name: UPWORK_CLIENT_ID
    value: "your-upwork-client-id"
  - name: UPWORK_CLIENT_SECRET
    value: "your-upwork-client-secret"
  - name: UPWORK_USER_AGENT
    value: "your-user-agent-string"
  - name: WEBHOOK_SECRET
    value: "your-webhook-secret"
  - name: DATABASE_URL
    value: "postgresql://user:pass@host:5432/db"
  # Optional variables
  - name: WEBHOOK_MAX_AGE_SECONDS
    value: "120"
  - name: API_PREFIX
    value: "/api/v1"
```

Or via command line:

**Using the public Helm repository:**

```bash
helm install solution-agent-orchestrator solution-agent-orchestrator/solution-agent-orchestrator \
  --set imagePullSecrets[0].name=ghcr-secret \
  --set env[0].name=API_JWT_SECRET \
  --set env[0].value="your-jwt-secret" \
  --set env[1].name=DATABASE_URL \
  --set env[1].value="postgresql://user:pass@host:5432/db" \
  --set env[2].name=SWAGGER_USERNAME \
  --set env[2].value="admin"
```

**Using a local chart:**

```bash
helm install solution-agent-orchestrator ./solution-agent-orchestrator \
  --set imagePullSecrets[0].name=ghcr-secret \
  --set env[0].name=API_JWT_SECRET \
  --set env[0].value="your-jwt-secret" \
  --set env[1].name=DATABASE_URL \
  --set env[1].value="postgresql://user:pass@host:5432/db" \
  --set env[2].name=SWAGGER_USERNAME \
  --set env[2].value="admin"
```

#### 2. Secrets (automatically converted to env vars)

For sensitive values, you can use the `secrets` section which automatically creates a Kubernetes secret:

```yaml
secrets:
  api_jwt_secret: "your-jwt-secret"
  swagger_password: "secure-password"
  upwork_client_secret: "your-upwork-secret"
  webhook_secret: "your-webhook-secret"
  database_url: "postgresql://user:pass@host:5432/db"
```

These will be automatically available as environment variables:
- `API_JWT_SECRET`
- `SWAGGER_PASSWORD`
- `UPWORK_CLIENT_SECRET`
- `WEBHOOK_SECRET`
- `DATABASE_URL`

Or via command line:

**Using the public Helm repository:**

```bash
helm install solution-agent-orchestrator solution-agent-orchestrator/solution-agent-orchestrator \
  --set imagePullSecrets[0].name=ghcr-secret \
  --set secrets.api_jwt_secret="your-jwt-secret" \
  --set secrets.database_url="postgresql://user:pass@host:5432/db"
```

**Using a local chart:**

```bash
helm install solution-agent-orchestrator ./solution-agent-orchestrator \
  --set imagePullSecrets[0].name=ghcr-secret \
  --set secrets.api_jwt_secret="your-jwt-secret" \
  --set secrets.database_url="postgresql://user:pass@host:5432/db"
```

## Configuration

The following table lists the configurable parameters and their default values:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `ghcr.io/your-org/solution-agent-orchestrator` |
| `image.tag` | Image tag (specify which version to deploy) | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Image pull secrets for private registries (e.g., GHCR) | `[]` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8000` |
| `ingress.enabled` | Enable ingress | `false` |
| `env` | Environment variables | `[]` |
| `secrets` | Secrets (auto-converted to env vars) | `{}` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `persistence.enabled` | Enable persistent volume | `false` |

## Examples

### Example 1: Basic Solution Agent Orchestrator with Required Environment Variables

```yaml
image:
  repository: ghcr.io/your-org/solution-agent-orchestrator
  tag: v1.0.0

imagePullSecrets:
  - name: ghcr-secret

env:
  # Required variables
  - name: API_JWT_SECRET
    value: "your-jwt-secret-here"
  - name: SWAGGER_USERNAME
    value: "admin"
  - name: SWAGGER_PASSWORD
    value: "secure-password"
  - name: UPWORK_CLIENT_ID
    value: "your-upwork-client-id"
  - name: UPWORK_CLIENT_SECRET
    value: "your-upwork-client-secret"
  - name: UPWORK_USER_AGENT
    value: "your-user-agent-string"
  - name: WEBHOOK_SECRET
    value: "your-webhook-secret"
  - name: DATABASE_URL
    value: "postgresql://user:pass@db:5432/mydb"
  # Optional variables
  - name: WEBHOOK_MAX_AGE_SECONDS
    value: "120"
  - name: API_PREFIX
    value: "/api/v1"

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

### Example 2: Solution Agent Orchestrator with Secrets and Ingress

```yaml
image:
  repository: ghcr.io/your-org/solution-agent-orchestrator
  tag: v1.2.3

imagePullSecrets:
  - name: ghcr-secret

# Using secrets for sensitive values
secrets:
  api_jwt_secret: "your-jwt-secret"
  swagger_password: "secure-password"
  upwork_client_secret: "your-upwork-secret"
  webhook_secret: "your-webhook-secret"
  database_url: "postgresql://user:pass@db:5432/mydb"

# Additional env vars via env section
env:
  - name: SWAGGER_USERNAME
    value: "admin"
  - name: UPWORK_CLIENT_ID
    value: "your-upwork-client-id"
  - name: UPWORK_USER_AGENT
    value: "your-user-agent-string"

ingress:
  enabled: true
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    - secretName: app-tls
      hosts:
        - app.example.com
```

### Example 3: Solution Agent Orchestrator with Persistent Storage

```yaml
image:
  repository: ghcr.io/your-org/solution-agent-orchestrator
  tag: v1.0.0

imagePullSecrets:
  - name: ghcr-secret

persistence:
  enabled: true
  size: 20Gi
  accessMode: ReadWriteOnce
  storageClass: fast-ssd

volumeMounts:
  - name: data
    mountPath: /app/data
```

### Example 4: Solution Agent Orchestrator with Custom Volumes

```yaml
image:
  repository: ghcr.io/your-org/solution-agent-orchestrator
  tag: v1.0.0

imagePullSecrets:
  - name: ghcr-secret

volumes:
  - name: config
    configMap:
      name: app-config
  - name: secrets
    secret:
      secretName: app-secrets

volumeMounts:
  - name: config
    mountPath: /app/config
    readOnly: true
  - name: secrets
    mountPath: /app/secrets
    readOnly: true
```

### Example 5: Deploying with Specific Tag via Helm Command

**Using the public Helm repository:**

```bash
# Add the repository first
helm repo add solution-agent-orchestrator https://neuro-inc.github.io/helm-charts
helm repo update

# Install with tag v1.2.3 and all required environment variables
helm install solution-agent-orchestrator solution-agent-orchestrator/solution-agent-orchestrator \
  --set image.repository=ghcr.io/your-org/solution-agent-orchestrator \
  --set image.tag=v1.2.3 \
  --set imagePullSecrets[0].name=ghcr-secret \
  --set env[0].name=API_JWT_SECRET \
  --set env[0].value="your-jwt-secret" \
  --set env[1].name=SWAGGER_USERNAME \
  --set env[1].value="admin" \
  --set env[2].name=SWAGGER_PASSWORD \
  --set env[2].value="secure-password" \
  --set env[3].name=UPWORK_CLIENT_ID \
  --set env[3].value="your-client-id" \
  --set env[4].name=UPWORK_CLIENT_SECRET \
  --set env[4].value="your-client-secret" \
  --set env[5].name=UPWORK_USER_AGENT \
  --set env[5].value="your-user-agent" \
  --set env[6].name=WEBHOOK_SECRET \
  --set env[6].value="your-webhook-secret" \
  --set env[7].name=DATABASE_URL \
  --set env[7].value="postgresql://user:pass@host:5432/db"

# Upgrade to new tag v1.2.4 (keeps existing env vars)
helm upgrade solution-agent-orchestrator solution-agent-orchestrator/solution-agent-orchestrator \
  --set image.tag=v1.2.4
```

**Using a local chart:**

```bash
# Install with tag v1.2.3 and all required environment variables
helm install solution-agent-orchestrator ./solution-agent-orchestrator \
  --set image.repository=ghcr.io/your-org/solution-agent-orchestrator \
  --set image.tag=v1.2.3 \
  --set imagePullSecrets[0].name=ghcr-secret \
  --set env[0].name=API_JWT_SECRET \
  --set env[0].value="your-jwt-secret" \
  --set env[1].name=SWAGGER_USERNAME \
  --set env[1].value="admin" \
  --set env[2].name=SWAGGER_PASSWORD \
  --set env[2].value="secure-password" \
  --set env[3].name=UPWORK_CLIENT_ID \
  --set env[3].value="your-client-id" \
  --set env[4].name=UPWORK_CLIENT_SECRET \
  --set env[4].value="your-client-secret" \
  --set env[5].name=UPWORK_USER_AGENT \
  --set env[5].value="your-user-agent" \
  --set env[6].name=WEBHOOK_SECRET \
  --set env[6].value="your-webhook-secret" \
  --set env[7].name=DATABASE_URL \
  --set env[7].value="postgresql://user:pass@host:5432/db"

# Upgrade to new tag v1.2.4 (keeps existing env vars)
helm upgrade solution-agent-orchestrator ./solution-agent-orchestrator \
  --set image.tag=v1.2.4
```

## Advanced Features

### Health Checks

Configure custom health check endpoints:

```yaml
livenessProbe:
  enabled: true
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  enabled: true
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
```

### Init Containers

```yaml
initContainers:
  - name: wait-for-db
    image: postgres:13
    command: ['sh', '-c', 'until pg_isready -h db; do sleep 1; done']
```

### Sidecar Containers

```yaml
sidecars:
  - name: log-shipper
    image: fluent/fluent-bit:latest
    volumeMounts:
      - name: varlog
        mountPath: /var/log
```

## Using Existing Secrets

If you have an existing secret, you can reference it:

```yaml
existingSecret: my-existing-secret
```

Or use `envFrom` to load all keys from a secret:

```yaml
envFrom:
  - secretRef:
      name: my-secret
```

## GitHub Container Registry (GHCR) Configuration

This chart is configured to work with GitHub Container Registry. To use it:

### 1. Create a GitHub Personal Access Token (PAT)

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate a new token with `read:packages` permission
3. Save the token securely

### 2. Create the Image Pull Secret

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<GITHUB_USERNAME> \
  --docker-password=<GITHUB_TOKEN> \
  --docker-email=<YOUR_EMAIL> \
  --namespace=<your-namespace>
```

### 3. Configure in values.yaml

```yaml
image:
  repository: ghcr.io/your-org/solution-agent-orchestrator
  tag: v1.2.3

imagePullSecrets:
  - name: ghcr-secret
```

### 4. Or specify via Helm command

**Using the public Helm repository:**

```bash
helm repo add solution-agent-orchestrator https://neuro-inc.github.io/helm-charts
helm repo update

helm install solution-agent-orchestrator solution-agent-orchestrator/solution-agent-orchestrator \
  --set imagePullSecrets[0].name=ghcr-secret \
  --set image.tag=v1.2.3
```

**Using a local chart:**

```bash
helm install solution-agent-orchestrator ./solution-agent-orchestrator \
  --set imagePullSecrets[0].name=ghcr-secret \
  --set image.tag=v1.2.3
```

**Note:** Make sure the secret exists in the namespace where you're deploying the application.

## Validation

**IMPORTANT:** Before deploying, ensure all **REQUIRED** environment variables are set:

### Required Variables (Must be set):
- `API_JWT_SECRET`
- `SWAGGER_USERNAME`
- `SWAGGER_PASSWORD`
- `UPWORK_CLIENT_ID`
- `UPWORK_CLIENT_SECRET`
- `UPWORK_USER_AGENT`
- `WEBHOOK_SECRET`
- `DATABASE_URL`

### Optional Variables (Have defaults):
- `WEBHOOK_PREVIOUS_SECRET` - Optional, for webhook secret rotation
- `WEBHOOK_MAX_AGE_SECONDS` - Default: `120`
- `API_PREFIX` - Default: `/api/v1`
- `UPWORK_OAUTH_TOKEN_URL` - Optional Upwork OAuth endpoint
- `UPWORK_API_BASE_URL` - Optional Upwork API base URL

You can verify environment variables after deployment:
```bash
kubectl get deployment <release-name> -n <namespace> -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' | tr ' ' '\n'
```

## Notes

- Environment variables from `secrets` are automatically converted to uppercase with underscores (e.g., `api_jwt_secret` becomes `API_JWT_SECRET`)
- The image tag can be easily changed during deployment using `--set image.tag=<tag>`
- Secrets are base64 encoded automatically
- Health check paths default to `/health` and `/ready` but can be customized
- Image pull secrets are required for private GitHub Container Registry images
- All required environment variables must be set for the application to start successfully

## Support

For issues and questions, please contact the DevOps team.

