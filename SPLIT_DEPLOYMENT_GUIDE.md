# Kubeflow Split Deployment Guide

## Problem

Some Kubeflow CRDs are extremely large (>800KB). When deployed through ArgoCD, Kubernetes adds a `kubectl.kubernetes.io/last-applied-configuration` annotation containing the entire CRD spec, which exceeds the 262KB annotation limit.

**Affected CRDs:**
- `clustertrainingruntimes.trainer.kubeflow.org` (874KB)
- `trainingruntimes.trainer.kubeflow.org`
- `inferenceservices.serving.kserve.io`
- `jobsets.jobset.x-k8s.io`
- `sparkapplications.sparkoperator.k8s.io`
- `scheduledsparkapplications.sparkoperator.k8s.io`

## Solution: Two-Part Deployment

### Part 1: Install Large CRDs Manually

Install the large CRDs using `kubectl apply --server-side` which doesn't add the problematic annotation:

```bash
cd /home/ml/kubeflow-manifests/kubeflow-part-1-crds
./install-crds.sh
```

Or manually:

```bash
kubectl apply --server-side=true --force-conflicts -f /home/ml/kubeflow-manifests/kubeflow-part-1-crds/large-crds/
```

**What this installs:**
- Trainer CRDs (ClusterTrainingRuntime, TrainingRuntime, TrainJob)
- JobSet CRDs
- Spark Operator CRDs (from applications/spark)

### Part 2: Deploy Everything Else via ArgoCD

After Part 1 is complete, deploy the rest via ArgoCD:

```bash
kubectl apply -f /home/ml/kubeflow-manifests/kubeflow-all-in-one/argocd-application.yaml
```

**Important:** The ArgoCD application will try to apply ALL resources including the CRDs. Since the CRDs are already installed from Part 1, ArgoCD will see them as "Synced" but may still try to patch them, causing the annotation error.

## Alternative: Exclude CRDs from ArgoCD

To prevent ArgoCD from managing the large CRDs at all, you need to exclude them from the kustomization. This requires modifying the upstream kustomizations.

### Option A: Use Resource Exclusions in ArgoCD Application

Add this to your ArgoCD Application spec:

```yaml
spec:
  ignoreDifferences:
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    name: clustertrainingruntimes.trainer.kubeflow.org
    jsonPointers:
    - /metadata/annotations
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    name: trainingruntimes.trainer.kubeflow.org
    jsonPointers:
    - /metadata/annotations
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    name: inferenceservices.serving.kserve.io
    jsonPointers:
    - /metadata/annotations
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    name: jobsets.jobset.x-k8s.io
    jsonPointers:
    - /metadata/annotations
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    name: sparkapplications.sparkoperator.k8s.io
    jsonPointers:
    - /metadata/annotations
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    name: scheduledsparkapplications.sparkoperator.k8s.io
    jsonPointers:
    - /metadata/annotations
```

This tells ArgoCD to ignore differences in annotations for these CRDs, but it will still try to apply them initially.

### Option B: Completely Exclude CRDs from ArgoCD (Recommended)

1. Install CRDs manually (Part 1)
2. Modify kustomization to exclude CRD resources
3. Deploy via ArgoCD (Part 2)

## Recommended Workflow

### Step 1: Install CRDs
```bash
cd /home/ml/kubeflow-manifests/kubeflow-part-1-crds
./install-crds.sh
```

Verify:
```bash
kubectl get crd | grep -E "(trainer|kserve|jobset|spark)"
```

### Step 2: Wait for CRDs to be Established
```bash
kubectl wait --for condition=established --timeout=60s crd/clustertrainingruntimes.trainer.kubeflow.org
kubectl wait --for condition=established --timeout=60s crd/trainingruntimes.trainer.kubeflow.org
kubectl wait --for condition=established --timeout=60s crd/trainjobs.trainer.kubeflow.org
```

### Step 3: Deploy Kubeflow via ArgoCD

**Option 1: Accept the annotation warnings**
```bash
kubectl delete application kubeflow -n argocd 2>/dev/null || true
kubectl apply -f /home/ml/kubeflow-manifests/kubeflow-all-in-one/argocd-application.yaml
```

ArgoCD will show errors about CRD annotations, but since the CRDs are already installed, the deployment will proceed with other resources.

**Option 2: Use ignore differences (cleaner)**

Update the ArgoCD application first, then apply:
```bash
# Edit argocd-application.yaml to add ignoreDifferences (see Option A above)
kubectl apply -f /home/ml/kubeflow-manifests/kubeflow-all-in-one/argocd-application.yaml
```

## Verification

After deployment:

```bash
# Check CRDs
kubectl get crd | grep -E "(kubeflow|kserve|trainer|spark|jobset)"

# Check applications
kubectl get pods -n kubeflow
kubectl get pods -n kubeflow-system

# Check ArgoCD status
kubectl get application kubeflow -n argocd
```

## Troubleshooting

### CRDs Still Showing Annotation Errors

If you still see annotation errors after installing CRDs manually:

1. The CRDs are already installed, so the errors are cosmetic
2. Add `ignoreDifferences` to your ArgoCD application (see Option A)
3. Or manually patch the CRDs to remove the annotation:
   ```bash
   kubectl annotate crd clustertrainingruntimes.trainer.kubeflow.org kubectl.kubernetes.io/last-applied-configuration-
   ```

### ArgoCD Stuck on CRD Sync

If ArgoCD is stuck trying to sync CRDs:

1. Delete the application: `kubectl delete application kubeflow -n argocd`
2. Verify CRDs are installed: `kubectl get crd | grep trainer`
3. Recreate application with `ignoreDifferences`

## Summary

The root cause is that large CRDs (>262KB after annotations) cannot be managed by ArgoCD's default apply mechanism. The solution is to:

1. **Install large CRDs manually** using `kubectl apply --server-side`
2. **Configure ArgoCD** to ignore annotation differences on these CRDs
3. **Deploy everything else** normally via ArgoCD

This two-part approach ensures all components are deployed successfully without hitting Kubernetes annotation limits.

