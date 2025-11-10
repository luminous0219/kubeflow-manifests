# Kubeflow Helm Chart

Complete Kubeflow deployment as a Helm chart, converted from Kustomize manifests.

## Why Helm Instead of Kustomize?

**Problem**: Large CRDs (>800KB) exceed Kubernetes' 262KB annotation limit when deployed via ArgoCD with Kustomize.

**Solution**: Helm stores release data in Secrets (not annotations), avoiding size limits entirely.

## Features

✅ **No annotation size limits** - Helm uses Secrets for metadata
✅ **Single deployment** - All components in one chart
✅ **ArgoCD compatible** - Native Helm support
✅ **Configurable** - Comprehensive values.yaml
✅ **GitOps ready** - Deploy via ArgoCD Application

## Quick Start

### Deploy via ArgoCD (Recommended)

```bash
kubectl apply -f argocd-application.yaml
```

### Deploy via Helm CLI

```bash
helm install kubeflow . --namespace kubeflow --create-namespace
```

## Configuration

Edit `values.yaml` or override values in ArgoCD Application:

```yaml
global:
  domain: "kubeflow.yourdomain.com"
  storageClass: "longhorn"
  istio:
    gateway:
      namespace: "istio-system"
  certManager:
    issuer: "letsencrypt-prod"

# Enable/disable components
centralDashboard:
  enabled: true
jupyter:
  enabled: true
katib:
  enabled: true
kserve:
  enabled: true
trainer:
  enabled: true
pipelines:
  enabled: false  # Complex setup, disabled by default
```

## Components Included

- **Auth**: Dex + OAuth2-Proxy
- **Knative**: Serving (for KServe)
- **Central Dashboard**: Main UI
- **Profiles**: Multi-tenancy
- **Jupyter**: Notebooks
- **Katib**: Hyperparameter tuning
- **KServe**: Model serving
- **Trainer**: Training operator v2
- **Tensorboard**: Visualization
- **Volumes Web App**: PVC management
- **Spark Operator**: Spark jobs

## Architecture

```
ArgoCD Application (Helm)
    ↓
Helm Release (kubeflow)
    ↓
├── CRDs (37 CRDs in crds/)
├── Namespaces
├── RBAC
├── ConfigMaps & Secrets
├── Services
├── Deployments
├── StatefulSets
└── Custom Resources
```

## Prerequisites

- Kubernetes 1.28+
- **Istio** (with ingress gateway)
- **cert-manager** (with ClusterIssuer)
- **Longhorn** (or other storage class)
- ArgoCD (for GitOps deployment)

## Deployment

### Step 1: Verify Prerequisites

```bash
# Check Istio
kubectl get pods -n istio-system

# Check cert-manager
kubectl get clusterissuer

# Check storage
kubectl get storageclass
```

### Step 2: Configure Values

Edit `argocd-application.yaml` or `values.yaml` with your settings:
- Domain name
- Storage class name
- Cert-manager issuer name

### Step 3: Deploy

```bash
kubectl apply -f argocd-application.yaml
```

### Step 4: Monitor

```bash
# Watch ArgoCD
kubectl get application kubeflow -n argocd

# Watch pods
watch kubectl get pods -n kubeflow
```

## Verification

```bash
# Check Helm release
helm list -n kubeflow

# Check CRDs
kubectl get crd | grep kubeflow

# Check pods
kubectl get pods -n kubeflow

# Check gateway
kubectl get gateway -n kubeflow
```

## Troubleshooting

### Helm Release Not Found

Check ArgoCD application:
```bash
kubectl describe application kubeflow -n argocd
```

### CRDs Not Installing

CRDs are in `crds/` folder and install automatically with Helm.

Verify:
```bash
kubectl get crd | grep -E "(kubeflow|kserve|trainer)"
```

### Pods Stuck in Pending

Check PVCs:
```bash
kubectl get pvc -n kubeflow
```

Verify storage class exists:
```bash
kubectl get storageclass
```

## Upgrading

```bash
# Via ArgoCD (automatic with selfHeal)
kubectl get application kubeflow -n argocd

# Via Helm CLI
helm upgrade kubeflow . --namespace kubeflow
```

## Uninstalling

```bash
# Via ArgoCD
kubectl delete application kubeflow -n argocd

# Via Helm
helm uninstall kubeflow --namespace kubeflow

# Delete CRDs (WARNING: Deletes all custom resources!)
kubectl delete crd -l app.kubernetes.io/name=kubeflow
```

## Customization

### Enable/Disable Components

In `values.yaml`:
```yaml
pipelines:
  enabled: false  # Disable pipelines

katib:
  enabled: true   # Enable Katib
```

### Change Resource Limits

```yaml
centralDashboard:
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
```

### Add Node Selectors

```yaml
nodeSelector:
  kubernetes.io/hostname: "worker-1"
```

## Development

### Regenerate Templates

If you modify the kustomize bases:

```bash
./generate-templates.sh
```

This rebuilds all templates from the kustomize output.

### Test Locally

```bash
# Lint
helm lint .

# Dry run
helm install kubeflow . --dry-run --debug

# Template
helm template kubeflow . > output.yaml
```

## Benefits Over Kustomize

| Feature | Kustomize | Helm |
|---------|-----------|------|
| Annotation Size | 262KB limit | No limit (uses Secrets) |
| ArgoCD Support | Native | Native |
| Configuration | Patches | values.yaml |
| Templating | Limited | Full Go templates |
| Release Management | None | Built-in |
| Rollback | Manual | `helm rollback` |

## Support

For issues:
- Check ArgoCD application status
- Review Helm release: `helm status kubeflow -n kubeflow`
- Check logs: `kubectl logs -n kubeflow <pod-name>`

## License

Apache 2.0 (same as Kubeflow)

