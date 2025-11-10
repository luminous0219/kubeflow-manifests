# Kubeflow CRD Deployment via Helm Chart

## Problem Solved

Large Kubeflow CRDs (>800KB) cannot be deployed via ArgoCD with kustomize because:
- ArgoCD/kubectl adds `last-applied-configuration` annotation
- This annotation contains the entire CRD spec
- Total annotations exceed Kubernetes' 262KB limit

## Solution: Helm Chart

Helm handles large CRDs better because:
1. **Helm stores release data in Secrets** (not annotations)
2. **Helm's three-way merge** doesn't add large annotations to resources
3. **ArgoCD can deploy Helm charts** without annotation issues
4. **CRDs in `crds/` folder** are installed before templates

## Deployment Steps

### Step 1: Deploy CRDs via Helm (ArgoCD)

```bash
kubectl apply -f /home/ml/kubeflow-manifests/kubeflow-crds-helm/argocd-application.yaml
```

This creates an ArgoCD Application named `kubeflow-crds` that:
- Deploys the Helm chart from your git repository
- Installs all large CRDs (Trainer, JobSet, Spark)
- Uses Helm's release management (no annotation bloat)

### Step 2: Wait for CRDs to be Established

```bash
# Watch CRDs being created
watch kubectl get crd | grep -E "(trainer|spark|jobset)"

# Or wait for specific CRDs
kubectl wait --for condition=established --timeout=60s \
  crd/clustertrainingruntimes.trainer.kubeflow.org \
  crd/trainingruntimes.trainer.kubeflow.org \
  crd/trainjobs.trainer.kubeflow.org
```

### Step 3: Deploy Kubeflow Applications

```bash
kubectl apply -f /home/ml/kubeflow-manifests/kubeflow-all-in-one/argocd-application.yaml
```

## Verification

```bash
# Check CRD application
kubectl get application kubeflow-crds -n argocd

# Check CRDs
kubectl get crd | grep -E "(trainer|spark|jobset)"

# Check Helm release
helm list -A | grep kubeflow-crds
```

## Architecture

```
┌─────────────────────────────────────────┐
│  ArgoCD Application: kubeflow-crds      │
│  (Helm Chart)                           │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Helm Release: kubeflow-crds            │
│  - Stores data in Secrets               │
│  - No annotation size limits            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  CRDs Installed:                        │
│  - clustertrainingruntimes              │
│  - trainingruntimes                     │
│  - trainjobs                            │
│  - sparkapplications                    │
│  - scheduledsparkapplications           │
│  - sparkconnects                        │
└─────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  ArgoCD Application: kubeflow           │
│  (Kustomize)                            │
│  - Deploys all applications             │
│  - Uses pre-installed CRDs              │
└─────────────────────────────────────────┘
```

## Why This Works

### Helm vs Kubectl/Kustomize

| Aspect | Kubectl/Kustomize | Helm |
|--------|-------------------|------|
| Metadata Storage | Annotations on resources | Secrets (separate) |
| Annotation Size | Adds `last-applied-configuration` | No large annotations |
| Size Limit | 262KB per resource | No limit (Secrets can be large) |
| CRD Handling | Problematic for large CRDs | Designed for CRDs |

### ArgoCD + Helm

ArgoCD has native Helm support:
- Detects Helm charts automatically
- Uses `helm template` to render manifests
- Applies manifests without annotation bloat
- Tracks Helm releases properly

## Troubleshooting

### CRDs Still Showing Errors

If you see annotation errors:
1. Delete the old kustomize-based application
2. Ensure you're using the Helm chart approach
3. Check that ArgoCD detected it as a Helm chart

```bash
kubectl get application kubeflow-crds -n argocd -o yaml | grep -A 5 "source:"
# Should show: helm: {}
```

### Helm Release Not Found

If Helm release is missing:
```bash
# Check ArgoCD application
kubectl describe application kubeflow-crds -n argocd

# Check for errors
kubectl get application kubeflow-crds -n argocd -o yaml | grep -A 20 "conditions:"
```

### CRDs Not Installing

Check the Helm chart structure:
```bash
# CRDs should be in crds/ folder
ls -la /home/ml/kubeflow-manifests/kubeflow-crds-helm/crds/

# Helm should detect them
helm template kubeflow-crds /home/ml/kubeflow-manifests/kubeflow-crds-helm/ --show-only crds/
```

## Cleanup

To remove everything:

```bash
# Delete applications
kubectl delete application kubeflow -n argocd
kubectl delete application kubeflow-crds -n argocd

# Delete CRDs (this will delete all custom resources!)
kubectl delete crd clustertrainingruntimes.trainer.kubeflow.org
kubectl delete crd trainingruntimes.trainer.kubeflow.org
kubectl delete crd trainjobs.trainer.kubeflow.org
```

## Summary

✅ **Problem**: Large CRDs exceed 262KB annotation limit with kustomize/kubectl
✅ **Solution**: Deploy CRDs via Helm chart (no annotation bloat)
✅ **Result**: ArgoCD can deploy everything without errors

**Deployment Order**:
1. `kubeflow-crds` (Helm chart) → Installs CRDs
2. `kubeflow` (Kustomize) → Deploys applications

This approach combines the best of both worlds:
- **Helm** for large CRDs (no size limits)
- **Kustomize** for applications (flexible configuration)

