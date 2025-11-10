# ArgoCD Troubleshooting Guide for Kubeflow

This guide helps you troubleshoot common ArgoCD issues when deploying Kubeflow.

## 🔍 Common Errors and Solutions

### Error: "Namespace for ... ConfigMap is missing"

**Full Error:**
```
InvalidSpecError
Namespace for default-install-config-9h2h2b6hbk /v1, Kind=ConfigMap is missing.
```

**Cause:** Kustomize generates ConfigMaps with hash suffixes, but ArgoCD validates resources before namespaces are created.

**Solutions:**

#### Solution 1: Sync with Retry (Recommended)

The ArgoCD application is configured with automatic retries. Simply click **Sync** in the ArgoCD UI:

1. Go to ArgoCD UI
2. Find the `kubeflow` application
3. Click **Sync** → **Synchronize**
4. ArgoCD will retry automatically (up to 10 times)
5. Wait for the sync to complete

The retry mechanism will handle namespace creation order automatically.

#### Solution 2: Manual Namespace Creation

Create namespaces manually before syncing:

```bash
kubectl create namespace kubeflow
kubectl create namespace auth
kubectl create namespace oauth2-proxy
kubectl create namespace knative-serving
```

Then sync the application.

#### Solution 3: Sync in Waves

If you want more control, sync in stages:

```bash
# Stage 1: Create namespaces
argocd app sync kubeflow --resource :Namespace:

# Stage 2: Sync everything else
argocd app sync kubeflow
```

#### Solution 4: Use Server-Side Apply

The application is already configured with `ServerSideApply=true`, which helps with this issue. If you're still seeing errors, ensure your ArgoCD version supports server-side apply (v2.5+).

### Error: "CRD not found" or "Unknown resource type"

**Cause:** Custom Resource Definitions (CRDs) need to be installed before Custom Resources (CRs).

**Solution:**

```bash
# Sync CRDs first
argocd app sync kubeflow --resource :CustomResourceDefinition:

# Wait for CRDs to be established
sleep 10

# Sync everything
argocd app sync kubeflow
```

### Error: "Webhook connection refused"

**Cause:** Webhook pods are not ready yet when ArgoCD tries to apply resources.

**Solution:**

Wait for webhook pods to be ready:

```bash
# Check webhook pods
kubectl get pods -n kubeflow | grep webhook
kubectl get pods -n cert-manager | grep webhook

# Wait for them to be ready
kubectl wait --for=condition=Ready pod -l app=webhook --timeout=300s -n kubeflow

# Retry sync
argocd app sync kubeflow
```

### Error: "Resource already exists"

**Cause:** Resources were created outside of ArgoCD or from a previous installation.

**Solution:**

```bash
# Option 1: Let ArgoCD take ownership
argocd app sync kubeflow --force

# Option 2: Delete conflicting resources
kubectl delete <resource-type> <resource-name> -n <namespace>

# Then sync again
argocd app sync kubeflow
```

### Error: "Sync failed: ComparisonError"

**Cause:** ArgoCD cannot compare resources due to missing fields or schema issues.

**Solution:**

The application is configured with `SkipDryRunOnMissingResource=true`. If you still see this:

```bash
# Force sync without dry-run
argocd app sync kubeflow --force
```

## 🔧 ArgoCD Configuration Tips

### Enable Auto-Sync (After Initial Deployment)

Once the initial deployment is successful, enable auto-sync:

```bash
# Edit the application
kubectl edit application kubeflow -n argocd

# Uncomment the automated section:
# syncPolicy:
#   automated:
#     prune: true
#     selfHeal: true
```

Or via CLI:

```bash
argocd app set kubeflow --sync-policy automated --auto-prune --self-heal
```

### Adjust Retry Settings

If deployments are slow, increase retry limits:

```yaml
syncPolicy:
  retry:
    limit: 20  # Increase from 10
    backoff:
      duration: 15s  # Increase from 10s
      maxDuration: 10m  # Increase from 5m
```

### Ignore Specific Differences

If ArgoCD keeps showing resources as out-of-sync:

```yaml
ignoreDifferences:
- group: apps
  kind: Deployment
  jsonPointers:
  - /spec/replicas  # Ignore if using HPA
```

## 📊 Monitoring ArgoCD Sync

### Check Application Status

```bash
# Get application status
argocd app get kubeflow

# Watch sync progress
argocd app sync kubeflow --watch

# Get sync history
argocd app history kubeflow
```

### Check Resource Status

```bash
# List all resources
argocd app resources kubeflow

# Check specific resource
argocd app resources kubeflow --kind Deployment --name ml-pipeline

# Get resource details
kubectl get deployment ml-pipeline -n kubeflow -o yaml
```

### View Sync Logs

```bash
# Get sync operation logs
argocd app logs kubeflow

# Get specific resource logs
argocd app logs kubeflow --kind Deployment --name ml-pipeline
```

## 🔄 Sync Strategies

### Strategy 1: Full Sync (Default)

Sync everything at once:

```bash
argocd app sync kubeflow
```

**Pros:** Simple, fast  
**Cons:** May fail on first attempt due to dependencies

### Strategy 2: Selective Sync

Sync specific resources:

```bash
# Sync namespaces first
argocd app sync kubeflow --resource :Namespace:

# Sync CRDs
argocd app sync kubeflow --resource :CustomResourceDefinition:

# Sync everything else
argocd app sync kubeflow
```

**Pros:** More control, handles dependencies better  
**Cons:** More manual steps

### Strategy 3: Sync with Prune

Remove resources that are no longer in Git:

```bash
argocd app sync kubeflow --prune
```

**Pros:** Keeps cluster in sync with Git  
**Cons:** May delete resources you want to keep

### Strategy 4: Force Sync

Override existing resources:

```bash
argocd app sync kubeflow --force
```

**Pros:** Fixes ownership issues  
**Cons:** May cause temporary downtime

## 🐛 Debugging Commands

### Check ArgoCD Application

```bash
# Get application details
kubectl get application kubeflow -n argocd -o yaml

# Check application status
kubectl get application kubeflow -n argocd -o jsonpath='{.status.sync.status}'

# Check sync conditions
kubectl get application kubeflow -n argocd -o jsonpath='{.status.conditions}'
```

### Check ArgoCD Server

```bash
# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Check ArgoCD application controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check ArgoCD repo server logs
kubectl logs -n argocd deployment/argocd-repo-server
```

### Check Kustomize Build

Test kustomize build locally:

```bash
cd kubeflow-manifests/kubeflow-all-in-one

# Build and check for errors
kustomize build . > /tmp/kubeflow-build.yaml

# Check for namespace issues
grep -A 5 "kind: ConfigMap" /tmp/kubeflow-build.yaml | grep -B 5 "namespace:"

# Count resources
grep "^kind:" /tmp/kubeflow-build.yaml | sort | uniq -c
```

### Validate Resources

```bash
# Validate with kubectl
kustomize build . | kubectl apply --dry-run=client -f -

# Validate with server-side dry-run
kustomize build . | kubectl apply --dry-run=server -f -
```

## 🔐 Common Configuration Issues

### Issue: Repository Not Accessible

**Error:** "Unable to clone repository"

**Solution:**

```bash
# Check repository credentials
argocd repo list

# Add repository if missing
argocd repo add https://github.com/kubeflow/manifests.git

# For private repos, add credentials
argocd repo add https://github.com/YOUR_ORG/manifests.git \
  --username YOUR_USERNAME \
  --password YOUR_TOKEN
```

### Issue: Target Revision Not Found

**Error:** "Unable to resolve revision"

**Solution:**

```bash
# Check if branch/tag exists
git ls-remote https://github.com/kubeflow/manifests.git | grep master

# Update target revision in application
kubectl patch application kubeflow -n argocd --type merge -p '{"spec":{"source":{"targetRevision":"main"}}}'
```

### Issue: Path Not Found

**Error:** "Path does not exist"

**Solution:**

```bash
# Verify path exists in repository
git clone https://github.com/kubeflow/manifests.git /tmp/manifests
ls -la /tmp/manifests/kubeflow-all-in-one/

# Update path in application
kubectl patch application kubeflow -n argocd --type merge -p '{"spec":{"source":{"path":"kubeflow-all-in-one"}}}'
```

## 📝 Best Practices

### 1. Use Git Repository

Always deploy from Git, not local files:

```yaml
source:
  repoURL: https://github.com/YOUR_ORG/manifests.git
  targetRevision: main
  path: kubeflow-all-in-one
```

### 2. Enable Health Checks

ArgoCD automatically checks health for standard resources. For custom resources:

```yaml
# Add to argocd-cm ConfigMap
resource.customizations: |
  kubeflow.org/Profile:
    health.lua: |
      hs = {}
      if obj.status ~= nil then
        if obj.status.conditions ~= nil then
          for i, condition in ipairs(obj.status.conditions) do
            if condition.type == "Ready" and condition.status == "False" then
              hs.status = "Degraded"
              hs.message = condition.message
              return hs
            end
            if condition.type == "Ready" and condition.status == "True" then
              hs.status = "Healthy"
              hs.message = "Profile is ready"
              return hs
            end
          end
        end
      end
      hs.status = "Progressing"
      hs.message = "Waiting for Profile"
      return hs
```

### 3. Use Sync Waves

Add sync wave annotations to control order:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy first
```

### 4. Monitor Resource Usage

```bash
# Check ArgoCD resource usage
kubectl top pods -n argocd

# Increase resources if needed
kubectl edit deployment argocd-application-controller -n argocd
```

### 5. Regular Cleanup

```bash
# Clean up old sync operations
argocd app history kubeflow --revision 1 --delete

# Prune unused resources
argocd app sync kubeflow --prune
```

## 🆘 Getting Help

If you're still experiencing issues:

1. **Check ArgoCD logs:**
   ```bash
   kubectl logs -n argocd deployment/argocd-application-controller --tail=100
   ```

2. **Check application events:**
   ```bash
   kubectl describe application kubeflow -n argocd
   ```

3. **Test kustomize build locally:**
   ```bash
   cd kubeflow-all-in-one
   kustomize build . | kubectl apply --dry-run=client -f -
   ```

4. **Ask the community:**
   - ArgoCD Slack: #argo-cd on CNCF Slack
   - Kubeflow Slack: #kubeflow-platform on CNCF Slack
   - GitHub Issues: kubeflow/manifests

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/)
- [Kubeflow Manifests](https://github.com/kubeflow/manifests)

---

**Quick Fix for Most Issues:**

```bash
# Delete and recreate the application
kubectl delete application kubeflow -n argocd
kubectl apply -f argocd-application.yaml

# Wait a moment, then sync
sleep 10
argocd app sync kubeflow
```

This usually resolves most transient issues! 🚀

