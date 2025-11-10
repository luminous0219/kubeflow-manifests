# Sync Waves vs Resource Conflicts - What You Need to Know

## 🤔 The Confusion

You might think: "If sync waves control deployment order, why do we still get resource conflicts?"

## 📝 The Answer

**Sync waves solve deployment-time issues, not build-time issues.**

### Build Time vs Deploy Time

```
Kustomize Build (Local)
  ↓
  Detects duplicate ClusterRole
  ↓
  ERROR: "may not add resource with an already registered id"
  ↓
  Build fails - ArgoCD never gets the manifests
  
(Sync waves never get a chance to run!)
```

vs

```
Kustomize Build (Success)
  ↓
  Manifests sent to ArgoCD
  ↓
  ArgoCD applies Wave 1 (Namespaces)
  ↓
  ArgoCD applies Wave 2 (CRDs, ClusterRoles)
  ↓
  ArgoCD applies Wave 3-9...
  ↓
  SUCCESS
```

## 🔍 The Metacontroller Conflict

### What Happens

1. **Kustomize starts building** the manifests
2. **Profiles component** includes metacontroller (indirectly)
3. **Pipelines component** includes metacontroller (directly)
4. **Kustomize sees the same ClusterRole twice** during build
5. **Build fails** with "may not add resource with an already registered id"
6. **ArgoCD never receives the manifests** to deploy

### Why Sync Waves Don't Help Here

Sync waves are **annotations on the built manifests**. They tell ArgoCD:
- "Deploy this in wave 1"
- "Deploy this in wave 2"
- "Wait for wave 1 to be healthy before starting wave 2"

But if Kustomize can't build the manifests in the first place, ArgoCD never sees them!

## ✅ What Sync Waves DO Solve

Sync waves are perfect for:

### 1. Namespace Before Resources
```yaml
# Wave 1: Create namespace
kind: Namespace
metadata:
  name: kubeflow
  annotations:
    argocd.argoproj.io/sync-wave: "1"

# Wave 3: Create ConfigMap (after namespace exists)
kind: ConfigMap
metadata:
  namespace: kubeflow
  annotations:
    argocd.argoproj.io/sync-wave: "3"
```

### 2. CRDs Before CRs
```yaml
# Wave 2: Create CRD
kind: CustomResourceDefinition
metadata:
  name: profiles.kubeflow.org
  annotations:
    argocd.argoproj.io/sync-wave: "2"

# Wave 9: Create CR (after CRD is established)
kind: Profile
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "9"
```

### 3. Database Before Application
```yaml
# Wave 6: Deploy database
kind: StatefulSet
metadata:
  name: mysql
  annotations:
    argocd.argoproj.io/sync-wave: "6"

# Wave 7: Deploy app (after database is ready)
kind: Deployment
metadata:
  name: ml-pipeline
  annotations:
    argocd.argoproj.io/sync-wave: "7"
```

### 4. Webhook Pods Before Webhook Config
```yaml
# Wave 7: Deploy webhook pod
kind: Deployment
metadata:
  name: admission-webhook
  annotations:
    argocd.argoproj.io/sync-wave: "7"

# Wave 8: Create webhook config (after pod is ready)
kind: MutatingWebhookConfiguration
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "8"
```

## ❌ What Sync Waves DON'T Solve

### Kustomize Build-Time Conflicts

```yaml
# In base-a/kustomization.yaml
resources:
- clusterrole.yaml  # Creates kubeflow-metacontroller

# In base-b/kustomization.yaml
resources:
- clusterrole.yaml  # Also creates kubeflow-metacontroller

# In your kustomization.yaml
resources:
- base-a
- base-b  # ERROR: Duplicate resource!
```

**Sync waves can't fix this** because Kustomize fails before ArgoCD sees the manifests.

## 🔧 Solutions for Build-Time Conflicts

### Solution 1: Separate Applications (Recommended)

Deploy conflicting components as separate ArgoCD applications:

```bash
# App 1: Core Kubeflow (without pipelines)
kubectl apply -f argocd-application.yaml

# App 2: Pipelines (separate)
kubectl apply -f argocd-pipelines-application.yaml
```

**Why this works:**
- Each application builds independently
- No shared Kustomize build context
- No duplicate resources in the same build

### Solution 2: Exclude Duplicate Resources

Use Kustomize patches to exclude duplicates:

```yaml
# In kustomization.yaml
resources:
- ../applications/pipeline/...

patches:
# Delete the duplicate ClusterRole from pipelines
- target:
    kind: ClusterRole
    name: kubeflow-metacontroller
  patch: |-
    $patch: delete
```

**Problem:** This is fragile and breaks when upstream changes.

### Solution 3: Use Kustomize Components

Create a shared component for metacontroller:

```yaml
# In shared/metacontroller/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
resources:
- clusterrole.yaml

# In your kustomization.yaml
components:
- shared/metacontroller

resources:
- ../applications/pipeline/... # Without metacontroller
- ../applications/profiles/... # Without metacontroller
```

**Problem:** Requires modifying upstream manifests.

## 📊 Comparison

| Issue | Sync Waves | Separate Apps |
|-------|------------|---------------|
| **Namespace before ConfigMap** | ✅ Solves | ✅ Also solves |
| **CRD before CR** | ✅ Solves | ✅ Also solves |
| **Database before App** | ✅ Solves | ✅ Also solves |
| **Webhook pod before config** | ✅ Solves | ✅ Also solves |
| **Duplicate ClusterRole** | ❌ Can't solve | ✅ Solves |
| **Kustomize build conflicts** | ❌ Can't solve | ✅ Solves |

## 🎯 Recommended Approach

### For Kubeflow: Use Both!

1. **Separate applications** for components with conflicts (Pipelines)
2. **Sync waves** within each application for deployment order

```yaml
# argocd-application.yaml (Core Kubeflow)
# Uses sync waves for proper ordering
resources:
- auth
- dashboard
- jupyter
- katib
- kserve
# (No pipelines)

patches:
# Sync wave annotations
- target:
    kind: Namespace
  patch: |-
    - op: add
      path: /metadata/annotations/argocd.argoproj.io~1sync-wave
      value: "1"
```

```yaml
# argocd-pipelines-application.yaml (Pipelines)
# Also uses sync waves
resources:
- seaweedfs
- pipelines

patches:
# Sync wave annotations
- target:
    kind: StatefulSet
  patch: |-
    - op: add
      path: /metadata/annotations/argocd.argoproj.io~1sync-wave
      value: "6"
```

## 💡 Key Takeaways

1. **Sync waves = Deployment order** (ArgoCD level)
2. **Resource conflicts = Build problem** (Kustomize level)
3. **Sync waves can't fix build problems**
4. **Use separate apps for build conflicts**
5. **Use sync waves within each app for deployment order**

## 🎓 When to Use What

### Use Sync Waves When:
- ✅ Resources have dependencies (namespace, CRD, database, etc.)
- ✅ Need to wait for pods to be ready
- ✅ Want controlled rollout order
- ✅ All resources build successfully

### Use Separate Apps When:
- ✅ Kustomize build fails with duplicate resources
- ✅ Components are logically independent
- ✅ Want independent upgrade cycles
- ✅ Need different sync policies

### Use Both When:
- ✅ Complex application like Kubeflow
- ✅ Some components conflict, others don't
- ✅ Want best of both worlds

## ✅ Summary

**Sync waves are awesome for:**
- Controlling deployment order
- Waiting for dependencies
- Proper sequencing

**But they can't fix:**
- Kustomize build-time conflicts
- Duplicate resource IDs
- Shared ClusterRoles

**For Kubeflow:**
- Core components: One app with sync waves ✅
- Pipelines: Separate app with sync waves ✅
- Result: No conflicts, proper ordering 🎉

