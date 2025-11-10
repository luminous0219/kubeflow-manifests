# Kubeflow Deployment Strategy

## 🎯 Recommended Approach: Multi-Application Deployment

Based on real-world testing and ArgoCD best practices, we recommend deploying Kubeflow as **multiple ArgoCD applications** rather than a single monolithic application.

## 📦 Application Structure

### Application 1: Core Kubeflow (Required)
**File:** `argocd-application.yaml`

**Includes:**
- ✅ Authentication (Dex + OAuth2-Proxy)
- ✅ Central Dashboard
- ✅ Profiles & KFAM
- ✅ Jupyter Notebooks
- ✅ Katib (Hyperparameter Tuning)
- ✅ KServe (Model Serving)
- ✅ Training Operator
- ✅ Tensorboard
- ✅ Volumes Web App
- ✅ Spark Operator
- ✅ Network Policies
- ✅ Knative Serving

**Excludes:**
- ❌ Kubeflow Pipelines (deployed separately)
- ❌ SeaweedFS (deployed separately)

### Application 2: Kubeflow Pipelines (Optional)
**File:** `argocd-pipelines-application.yaml`

**Includes:**
- ✅ Kubeflow Pipelines API Server
- ✅ Argo Workflows
- ✅ MySQL Database
- ✅ MinIO Object Storage
- ✅ Metadata Store
- ✅ Cache Server
- ✅ Metacontroller

### Application 3: SeaweedFS (Optional)
**File:** `argocd-pipelines-application.yaml` (included)

**Includes:**
- ✅ SeaweedFS Master
- ✅ SeaweedFS Volume Servers
- ✅ S3 API Gateway

## 🤔 Why Separate Applications?

### Problem: Resource Conflicts

When deploying everything in a single kustomization, you may encounter:

```
Error: may not add resource with an already registered id: 
ClusterRole.v1.rbac.authorization.k8s.io/kubeflow-metacontroller.[noNs]
```

**Root Cause:**
- Multiple components (Pipelines, Profiles) include metacontroller
- Kustomize doesn't handle duplicate resources across multiple bases
- ArgoCD validation fails before resources are applied

### Solution: Separate Applications

By deploying as separate applications:

1. **No Resource Conflicts**
   - Each application has its own resource namespace
   - No duplicate resource IDs
   - Clean dependency management

2. **Better Control**
   - Deploy core components first
   - Add optional components later
   - Independent upgrade cycles

3. **Easier Troubleshooting**
   - Isolated failures
   - Clear component boundaries
   - Simpler rollback

4. **Follows ArgoCD Best Practices**
   - "App of Apps" pattern
   - Modular architecture
   - Independent sync policies

## 🚀 Deployment Steps

### Step 1: Deploy Core Kubeflow

```bash
# Apply the core application
kubectl apply -f argocd-application.yaml

# Sync and wait
argocd app sync kubeflow
argocd app wait kubeflow --health
```

**Expected Time:** 10-15 minutes

**Verify:**
```bash
kubectl get pods -n kubeflow
kubectl get pods -n auth
kubectl get pods -n oauth2-proxy
```

### Step 2: Deploy Pipelines (Optional)

```bash
# Apply pipelines applications
kubectl apply -f argocd-pipelines-application.yaml

# Sync SeaweedFS first
argocd app sync kubeflow-seaweedfs
argocd app wait kubeflow-seaweedfs --health

# Then sync Pipelines
argocd app sync kubeflow-pipelines
argocd app wait kubeflow-pipelines --health
```

**Expected Time:** 5-10 minutes

**Verify:**
```bash
kubectl get pods -n kubeflow | grep -E "ml-pipeline|seaweedfs|argo"
```

### Step 3: Verify Complete Deployment

```bash
# Check all applications
argocd app list

# Check all pods
kubectl get pods -A | grep -E "kubeflow|auth|oauth2"

# Access Kubeflow
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
```

## 🔄 Alternative: Single Application (Advanced)

If you prefer a single application despite the complexity:

### Option 1: Force Sync

```bash
# Uncomment pipelines in kustomization.yaml
vim kubeflow-all-in-one/kustomization.yaml

# Force sync (may fail first time)
argocd app sync kubeflow --force

# Retry if needed
argocd app sync kubeflow --force
```

### Option 2: Use Kustomize Components

Create a custom kustomization that uses components:

```yaml
# custom-kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
- ../applications/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user

# Override conflicting resources
patches:
- target:
    kind: ClusterRole
    name: kubeflow-metacontroller
  patch: |-
    $patch: delete
```

**Note:** This is complex and not recommended for most users.

## 📊 Comparison

| Aspect | Multi-App | Single App |
|--------|-----------|------------|
| **Complexity** | Low | High |
| **Resource Conflicts** | None | Common |
| **Deployment Time** | 15-20 min | 20-30 min |
| **Troubleshooting** | Easy | Difficult |
| **Upgrades** | Independent | All-or-nothing |
| **Rollback** | Per-component | All-or-nothing |
| **ArgoCD UI** | Clean | Cluttered |
| **Recommended** | ✅ Yes | ❌ No |

## 🎓 Best Practices

### 1. Start Small, Grow Later

```bash
# Day 1: Core components only
kubectl apply -f argocd-application.yaml

# Day 2: Add pipelines when ready
kubectl apply -f argocd-pipelines-application.yaml
```

### 2. Use App Projects

Organize applications by team or purpose:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: kubeflow
  namespace: argocd
spec:
  description: Kubeflow ML Platform
  sourceRepos:
  - https://github.com/kubeflow/manifests.git
  destinations:
  - namespace: 'kubeflow*'
    server: https://kubernetes.default.svc
```

### 3. Enable Auto-Sync Per Application

```bash
# Auto-sync core (stable)
argocd app set kubeflow --sync-policy automated --auto-prune --self-heal

# Manual sync for pipelines (more control)
argocd app set kubeflow-pipelines --sync-policy none
```

### 4. Use Sync Waves

Add annotations to control order:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy first
```

### 5. Monitor Application Health

```bash
# Watch all Kubeflow applications
watch 'argocd app list | grep kubeflow'

# Get detailed status
argocd app get kubeflow
argocd app get kubeflow-pipelines
```

## 🐛 Troubleshooting

### Applications Out of Sync

```bash
# Sync all Kubeflow applications
argocd app sync kubeflow kubeflow-seaweedfs kubeflow-pipelines

# Or sync individually
argocd app sync kubeflow
```

### Resource Conflicts

```bash
# Check for conflicts
argocd app get kubeflow --show-operation

# Force sync if needed
argocd app sync kubeflow --force
```

### Dependency Issues

```bash
# Ensure core is healthy before pipelines
argocd app wait kubeflow --health

# Then sync pipelines
argocd app sync kubeflow-pipelines
```

## 📚 Additional Resources

- **[ARGOCD-QUICKSTART.md](ARGOCD-QUICKSTART.md)** - Quick start guide
- **[ARGOCD-TROUBLESHOOTING.md](ARGOCD-TROUBLESHOOTING.md)** - Detailed troubleshooting
- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** - Complete deployment guide
- **[ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)** - Official documentation

## ✅ Summary

**Recommended Approach:**
1. Deploy core Kubeflow as one application
2. Deploy Pipelines as a separate application
3. Deploy SeaweedFS as a separate application (or with Pipelines)

**Benefits:**
- ✅ No resource conflicts
- ✅ Easier troubleshooting
- ✅ Independent upgrades
- ✅ Better control
- ✅ Follows best practices

**When to Use Single Application:**
- You have deep Kustomize knowledge
- You can handle resource conflicts
- You need everything deployed atomically
- You're willing to debug complex issues

For most users, **multi-application deployment is the way to go**! 🚀

