# ArgoCD Sync Waves Guide for Kubeflow

## 🌊 What Are Sync Waves?

Sync waves are ArgoCD's way of controlling the order in which resources are deployed. By assigning a wave number to each resource, you can ensure dependencies are met before dependent resources are created.

## 🎯 Why Use Sync Waves for Kubeflow?

### The Problem Without Sync Waves

When deploying Kubeflow as a single application, you might encounter:

1. **Resource Conflicts**: Multiple components try to create the same ClusterRole
2. **Missing Namespaces**: ConfigMaps created before their namespaces exist
3. **CRD Not Ready**: Custom Resources created before CRDs are established
4. **Webhook Errors**: Resources validated before webhook pods are ready

### The Solution With Sync Waves

Sync waves solve all these issues by deploying resources in the correct order:

```
Wave 1: Namespaces
  ↓
Wave 2: CRDs, ClusterRoles (including metacontroller)
  ↓
Wave 3: ServiceAccounts, Secrets, ConfigMaps
  ↓
Wave 4: Services, PVCs
  ↓
Wave 5: Istio Resources
  ↓
Wave 6: StatefulSets (databases)
  ↓
Wave 7: Deployments (applications)
  ↓
Wave 8: Webhooks
  ↓
Wave 9: Custom Resources (Profiles, etc.)
```

## 📋 Kubeflow Sync Wave Strategy

### Wave 1: Foundation (Namespaces)
**Resources:** All Namespace objects  
**Why First:** Everything else needs a namespace to exist in

```yaml
kind: Namespace
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

### Wave 2: Schema & RBAC (CRDs, ClusterRoles)
**Resources:** CustomResourceDefinitions, ClusterRoles, ClusterRoleBindings  
**Why Early:** CRDs must exist before CRs; RBAC needed for controllers

**Key Point:** The `kubeflow-metacontroller` ClusterRole is deployed here, so when Pipelines tries to create it later, it already exists (no conflict!)

```yaml
kind: CustomResourceDefinition
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
---
kind: ClusterRole
metadata:
  name: kubeflow-metacontroller
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

### Wave 3: Identity & Configuration
**Resources:** ServiceAccounts, Secrets, ConfigMaps  
**Why Now:** Deployments need these to start

```yaml
kind: ConfigMap
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "3"
```

### Wave 4: Networking & Storage
**Resources:** Services, PersistentVolumeClaims  
**Why Now:** Pods need services and storage to be available

```yaml
kind: Service
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "4"
```

### Wave 5: Service Mesh
**Resources:** Istio Gateways, VirtualServices, DestinationRules, PeerAuthentication  
**Why Now:** Mesh configuration before applications start

```yaml
kind: Gateway
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "5"
```

### Wave 6: Stateful Applications
**Resources:** StatefulSets (databases like MySQL, PostgreSQL)  
**Why Now:** Databases must be ready before applications

```yaml
kind: StatefulSet
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "6"
```

### Wave 7: Applications
**Resources:** Deployments (all Kubeflow services)  
**Why Now:** After all dependencies are ready

```yaml
kind: Deployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "7"
```

### Wave 8: Admission Control
**Resources:** MutatingWebhookConfiguration, ValidatingWebhookConfiguration  
**Why Last:** Webhook pods must be running first

```yaml
kind: MutatingWebhookConfiguration
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "8"
```

### Wave 9: User Resources
**Resources:** Profiles, Custom Resources  
**Why Last:** Controllers must be ready to reconcile these

```yaml
kind: Profile
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "9"
```

## 🔧 How It's Implemented

### In kustomization.yaml

The sync waves are added via Kustomize patches:

```yaml
patches:
# Wave 1: Namespaces
- target:
    kind: Namespace
  patch: |-
    - op: add
      path: /metadata/annotations
      value:
        argocd.argoproj.io/sync-wave: "1"

# Wave 2: CRDs and RBAC
- target:
    group: apiextensions.k8s.io
    kind: CustomResourceDefinition
  patch: |-
    - op: add
      path: /metadata/annotations
      value:
        argocd.argoproj.io/sync-wave: "2"

# ... more waves ...
```

### In ArgoCD Application

Auto-sync is enabled because sync waves handle ordering:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - ApplyOutOfSyncOnly=false  # Respect sync waves
```

## 🚀 Deployment with Sync Waves

### Simple Deployment

```bash
# 1. Apply the application
kubectl apply -f argocd-application.yaml

# 2. That's it! ArgoCD handles the rest
# Watch the waves deploy in order
argocd app get kubeflow --watch
```

### What You'll See

In the ArgoCD UI, you'll see resources deploying in waves:

```
Syncing Wave 1 (Namespaces)...
✓ Namespace/kubeflow
✓ Namespace/auth
✓ Namespace/oauth2-proxy

Syncing Wave 2 (CRDs, RBAC)...
✓ CustomResourceDefinition/profiles.kubeflow.org
✓ ClusterRole/kubeflow-metacontroller
✓ ClusterRole/kubeflow-admin

Syncing Wave 3 (ServiceAccounts, Secrets)...
✓ ServiceAccount/ml-pipeline
✓ Secret/dex-passwords
✓ ConfigMap/pipeline-install-config

... and so on ...
```

## 📊 Benefits of Sync Waves

### ✅ Single Application
- Everything in one ArgoCD application
- Simpler management
- Single source of truth

### ✅ No Resource Conflicts
- Metacontroller ClusterRole created once in Wave 2
- No duplicate resource errors
- Clean deployment

### ✅ Automatic Ordering
- Dependencies handled automatically
- No manual intervention needed
- Reliable deployments

### ✅ Better Observability
- Clear deployment progress
- Easy to see which wave is deploying
- Identify issues quickly

### ✅ Auto-Sync Safe
- Sync waves prevent race conditions
- Safe to enable automated sync
- Self-healing works correctly

## 🐛 Troubleshooting

### Wave Stuck or Failed

```bash
# Check which wave is stuck
argocd app get kubeflow

# Check resources in that wave
kubectl get all -n kubeflow -l argocd.argoproj.io/sync-wave=3

# Force sync that wave
argocd app sync kubeflow --resource :Deployment:ml-pipeline
```

### Resource Not in Expected Wave

```bash
# Check resource annotations
kubectl get deployment ml-pipeline -n kubeflow -o yaml | grep sync-wave

# If missing, the patch didn't apply
# Check kustomize build
kustomize build kubeflow-all-in-one | grep -A 5 "kind: Deployment" | grep sync-wave
```

### Sync Taking Too Long

Each wave waits for resources to be healthy before moving to the next wave.

```bash
# Check unhealthy resources
argocd app get kubeflow | grep -i "degraded\|progressing"

# Check pod status
kubectl get pods -n kubeflow | grep -v Running

# Check events
kubectl get events -n kubeflow --sort-by='.lastTimestamp'
```

## 🔄 Modifying Sync Waves

### Add Custom Wave

To deploy something in a specific order:

```yaml
# In kustomization.yaml
patches:
- target:
    kind: Deployment
    name: my-custom-app
  patch: |-
    - op: add
      path: /metadata/annotations/argocd.argoproj.io~1sync-wave
      value: "10"  # After everything else
```

### Change Wave Order

To deploy something earlier:

```yaml
patches:
- target:
    kind: StatefulSet
    name: my-database
  patch: |-
    - op: replace
      path: /metadata/annotations/argocd.argoproj.io~1sync-wave
      value: "5"  # Earlier than default wave 6
```

## 📚 ArgoCD Sync Wave Documentation

- **Official Docs**: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/
- **Best Practices**: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/

## 🎓 Advanced Patterns

### Sync Wave Hooks

Use hooks for pre/post sync actions:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
    argocd.argoproj.io/hook: PreSync
```

### Conditional Waves

Deploy different waves based on environment:

```yaml
# In kustomization.yaml for production
- target:
    kind: Deployment
  patch: |-
    - op: add
      path: /metadata/annotations/argocd.argoproj.io~1sync-wave
      value: "7"

# In kustomization.yaml for development
- target:
    kind: Deployment
  patch: |-
    - op: add
      path: /metadata/annotations/argocd.argoproj.io~1sync-wave
      value: "3"  # Deploy faster in dev
```

### Wave Dependencies

Ensure one component waits for another:

```yaml
# Database in wave 5
kind: StatefulSet
metadata:
  name: mysql
  annotations:
    argocd.argoproj.io/sync-wave: "5"

# Application in wave 6 (waits for database)
kind: Deployment
metadata:
  name: ml-pipeline
  annotations:
    argocd.argoproj.io/sync-wave: "6"
```

## ✅ Summary

**Sync waves provide:**
- ✅ Ordered deployment
- ✅ No resource conflicts
- ✅ Single application
- ✅ Auto-sync safe
- ✅ Better observability
- ✅ Reliable deployments

**Recommended for:**
- ✅ Production deployments
- ✅ Complex applications
- ✅ GitOps workflows
- ✅ Automated deployments

**Perfect for Kubeflow because:**
- ✅ Handles metacontroller conflict
- ✅ Ensures CRDs before CRs
- ✅ Deploys databases before apps
- ✅ Webhooks after pods ready
- ✅ Everything in one application

🎉 **Sync waves make Kubeflow deployment simple, reliable, and conflict-free!**

