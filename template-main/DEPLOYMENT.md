# Deployment Guide

This guide walks you through deploying applications using the Kubernetes Application Template.

## Prerequisites

Before deploying applications with this template, ensure you have:

- **Kubernetes cluster** (1.19+) with the following components:
  - **ArgoCD** for GitOps deployment
  - **Istio service mesh** (1.27+) with ingress gateway
  - **cert-manager** with Let's Encrypt ClusterIssuer
  - **Longhorn** or compatible storage provider
- **kubectl** configured to access your cluster
- **Helm** 3.2.0+ (for local testing)
- **Git repository** (GitLab recommended) for your application code

## Step-by-Step Deployment

### Step 1: Prepare Your Application Repository

1. **Create a new Git repository** for your application:
   ```bash
   git clone https://gitlab.com/your-username/my-new-app.git
   cd my-new-app
   ```

2. **Copy the template** to your repository:
   ```bash
   cp -r /path/to/template/* .
   git add .
   git commit -m "Initial commit: Add Kubernetes template"
   git push origin main
   ```

### Step 2: Customize Chart Metadata

Edit `Chart.yaml` with your application details:

```yaml
apiVersion: v2
name: "my-awesome-app"
description: "My awesome Kubernetes application"
type: application
version: "0.1.0"
appVersion: "1.0.0"
home: "https://my-awesome-app.com"
sources:
  - "https://github.com/myorg/my-awesome-app"
keywords:
  - web
  - api
  - microservice
maintainers:
  - name: "John Doe"
    email: "john.doe@company.com"
```

### Step 3: Configure Application Values

Edit `values.yaml` to match your application requirements:

#### Basic Application Configuration
```yaml
app:
  name: "my-awesome-app"
  description: "My awesome Kubernetes application"
  version: "1.0.0"
  homepage: "https://my-awesome-app.com"
  sourceUrl: "https://github.com/myorg/my-awesome-app"
  maintainer:
    name: "John Doe"
    email: "john.doe@company.com"

image:
  repository: "registry.company.com/my-awesome-app"
  tag: "1.0.0"
  pullPolicy: IfNotPresent

namespace:
  name: "my-awesome-app"
```

#### Network and Istio Configuration
```yaml
istio:
  enabled: true
  gateway:
    hosts:
      - "my-awesome-app.company.com"
  
service:
  port: 80
  targetPort: 8080  # Your application port

certManager:
  enabled: true
  issuer: "letsencrypt-prod"  # Your ClusterIssuer name
  secretName: "my-awesome-app-tls"
```

#### Resource and Scaling Configuration
```yaml
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

nodeSelector:
  kubernetes.io/hostname: "k8s-worker-2"  # Your target node

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

#### Storage Configuration (if needed)
```yaml
persistence:
  enabled: true
  storageClass: "longhorn-retain"
  size: 20Gi
  mountPath: "/app/data"
```

#### Environment Variables and Secrets
```yaml
env:
  - name: NODE_ENV
    value: "production"
  - name: LOG_LEVEL
    value: "info"

secrets:
  DATABASE_URL: "postgresql://user:password@db:5432/myapp"
  API_SECRET_KEY: "your-super-secret-key"
  REDIS_URL: "redis://redis:6379/0"
```

### Step 4: Configure ArgoCD Application

Edit `argocd-application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-awesome-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://gitlab.com/your-username/my-awesome-app.git
    targetRevision: HEAD
    path: .  # Root of repository
    helm:
      valueFiles:
        - values.yaml
      values: |
        # Override specific values for this deployment
        app:
          name: "my-awesome-app"
        image:
          repository: "registry.company.com/my-awesome-app"
          tag: "1.0.0"
        istio:
          gateway:
            hosts:
              - "my-awesome-app.company.com"
        # Add any environment-specific overrides here

  destination:
    server: https://kubernetes.default.svc
    namespace: my-awesome-app

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Step 5: Prepare Cluster Dependencies

Before deploying, ensure these cluster-wide dependencies are ready:

#### 1. Verify ClusterIssuer
```bash
kubectl get clusterissuer letsencrypt-prod
```

If not present, create one:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@company.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: istio
```

#### 2. Verify Istio Gateway
Check if you have a shared gateway or need to create one:
```bash
kubectl get gateway -n istio-system
```

#### 3. Verify Storage Classes
```bash
kubectl get storageclass
```

Ensure `longhorn-retain` or your chosen storage class exists.

### Step 6: Deploy the Application

1. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Configure application for deployment"
   git push origin main
   ```

2. **Apply the ArgoCD Application**:
   ```bash
   kubectl apply -f argocd-application.yaml
   ```

3. **Monitor the deployment**:
   ```bash
   # Watch ArgoCD application status
   kubectl get application my-awesome-app -n argocd -w
   
   # Check application sync status
   argocd app get my-awesome-app
   
   # View pods
   kubectl get pods -n my-awesome-app
   ```

### Step 7: Verify Deployment

#### 1. Check Pod Status
```bash
kubectl get pods -n my-awesome-app -l app.kubernetes.io/name=my-awesome-app
```

#### 2. Verify Istio Sidecar Injection
```bash
kubectl get pods -n my-awesome-app -o custom-columns=NAME:.metadata.name,CONTAINERS:.spec.containers[*].name
```

You should see both your application container and `istio-proxy`.

#### 3. Check Certificate Status
```bash
kubectl get certificate -n istio-system
kubectl describe certificate my-awesome-app-tls -n istio-system
```

#### 4. Test Application Access
```bash
# Test internal connectivity
kubectl exec -n my-awesome-app deployment/my-awesome-app -- curl -I http://localhost:8080/

# Test external access (replace with your domain)
curl -I https://my-awesome-app.company.com/
```

#### 5. View Application Logs
```bash
kubectl logs -n my-awesome-app -l app.kubernetes.io/name=my-awesome-app -f
```

## Environment-Specific Deployments

### Development Environment

For development deployments, you might want to:

```yaml
# values-dev.yaml
replicaCount: 1

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

istio:
  gateway:
    hosts:
      - "my-awesome-app-dev.company.com"

certManager:
  enabled: false  # Use self-signed certs for dev

autoscaling:
  enabled: false
```

### Staging Environment

For staging deployments:

```yaml
# values-staging.yaml
replicaCount: 2

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

istio:
  gateway:
    hosts:
      - "my-awesome-app-staging.company.com"

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
```

### Production Environment

For production deployments:

```yaml
# values-prod.yaml
replicaCount: 3

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi

istio:
  gateway:
    hosts:
      - "my-awesome-app.company.com"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 60

podDisruptionBudget:
  enabled: true
  minAvailable: 2

networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: istio-system
      ports:
      - protocol: TCP
        port: 8080
```

## Multi-Environment ArgoCD Setup

For multiple environments, create separate ArgoCD applications:

### Development Application
```yaml
# argocd-application-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-awesome-app-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://gitlab.com/your-username/my-awesome-app.git
    targetRevision: develop  # Use develop branch for dev
    path: .
    helm:
      valueFiles:
        - values.yaml
        - values-dev.yaml  # Dev-specific values
  destination:
    server: https://kubernetes.default.svc
    namespace: my-awesome-app-dev
  # ... rest of configuration
```

### Production Application
```yaml
# argocd-application-prod.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-awesome-app-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://gitlab.com/your-username/my-awesome-app.git
    targetRevision: main  # Use main branch for production
    path: .
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml  # Production-specific values
  destination:
    server: https://kubernetes.default.svc
    namespace: my-awesome-app-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: false  # Disable self-heal for production
  # ... rest of configuration
```

## Monitoring and Maintenance

### Health Checks

The template includes comprehensive health checks. Monitor them with:

```bash
# Check pod readiness and liveness
kubectl describe pod <pod-name> -n <namespace>

# View probe failures
kubectl get events -n <namespace> --field-selector type=Warning
```

### Scaling Operations

```bash
# Manual scaling
kubectl scale deployment my-awesome-app --replicas=5 -n my-awesome-app

# Check HPA status
kubectl get hpa -n my-awesome-app
kubectl describe hpa my-awesome-app -n my-awesome-app
```

### Certificate Management

```bash
# Check certificate status
kubectl get certificate -A

# Force certificate renewal
kubectl annotate certificate my-awesome-app-tls -n istio-system cert-manager.io/issue-temporary-certificate=true

# View certificate details
kubectl describe certificate my-awesome-app-tls -n istio-system
```

### Storage Management

```bash
# Check PVC status
kubectl get pvc -n my-awesome-app

# View storage usage
kubectl exec -n my-awesome-app deployment/my-awesome-app -- df -h

# Backup data (example with Longhorn)
kubectl annotate pvc my-awesome-app-pvc -n my-awesome-app longhorn.io/backup-name=backup-$(date +%Y%m%d-%H%M%S)
```

## Troubleshooting Deployment Issues

### Common Deployment Problems

#### 1. Image Pull Errors
```bash
# Check image pull secrets
kubectl get secret -n my-awesome-app
kubectl describe pod <pod-name> -n my-awesome-app

# Solution: Add image pull secrets
kubectl create secret docker-registry regcred \
  --docker-server=registry.company.com \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n my-awesome-app
```

#### 2. Istio Sidecar Issues
```bash
# Check sidecar status
istioctl proxy-status

# View sidecar configuration
istioctl proxy-config cluster <pod-name>.<namespace>

# Solution: The template includes manual sidecar injection as fallback
```

#### 3. Certificate Issues
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate challenges
kubectl get challenges -A

# Solution: Verify DNS settings and ClusterIssuer configuration
```

#### 4. Storage Issues
```bash
# Check storage class
kubectl get storageclass

# Check Longhorn system
kubectl get pods -n longhorn-system

# Solution: Verify storage provider is healthy
```

### ArgoCD Sync Issues

```bash
# Check application status
argocd app get my-awesome-app

# View sync history
argocd app history my-awesome-app

# Force sync
argocd app sync my-awesome-app

# Hard refresh
argocd app sync my-awesome-app --force
```

## Best Practices

### Security
- Always use specific image tags, avoid `latest`
- Configure resource limits and requests
- Enable network policies in production
- Use secrets for sensitive data
- Regularly update base images

### Performance
- Set appropriate resource requests and limits
- Configure HPA for variable workloads
- Use persistent volumes for stateful data
- Monitor application metrics

### Reliability
- Enable pod disruption budgets
- Configure proper health checks
- Use multiple replicas in production
- Implement graceful shutdown handling

### GitOps
- Use separate branches for different environments
- Implement proper CI/CD pipelines
- Tag releases properly
- Use ArgoCD sync waves for ordered deployment

This deployment guide should help you successfully deploy applications using the Kubernetes Application Template. For specific issues or questions, consult your DevOps team or platform documentation. 