# ArgoCD Quick Start for Kubeflow

## 🎯 TL;DR - Just Deploy It!

```bash
# 1. Apply the ArgoCD application
kubectl apply -f argocd-application.yaml

# 2. Watch it deploy (ArgoCD handles everything!)
argocd app get kubeflow --watch
```

That's it! **Sync waves** handle deployment order automatically.

**What happens:**
- Wave 1: Namespaces created
- Wave 2: CRDs and ClusterRoles (including metacontroller)
- Wave 3-9: Everything else in order
- No conflicts, no manual steps!

## ⚠️ Common First-Time Errors

### ✅ No Errors Expected!

With sync waves enabled, you shouldn't see the common errors anymore:

- ✅ **No resource conflicts** - Metacontroller ClusterRole created once in Wave 2
- ✅ **No missing namespaces** - Namespaces created in Wave 1
- ✅ **No CRD issues** - CRDs created in Wave 2 before CRs
- ✅ **No webhook errors** - Webhooks deployed in Wave 8 after pods ready

### If You Do See Errors

**Error: Resource Conflict**
```
Error: may not add resource with an already registered id
```

**Cause:** Sync wave patches didn't apply correctly.

**Solution:**
```bash
# Verify sync waves are applied
kustomize build kubeflow-all-in-one | grep -A 2 "kind: ClusterRole" | grep sync-wave

# If missing, rebuild and reapply
kubectl delete application kubeflow -n argocd
kubectl apply -f argocd-application.yaml
```

**Error: Sync Timeout**

**Cause:** A wave is taking too long (waiting for pods to be healthy).

**Solution:**
```bash
# Check which wave is stuck
argocd app get kubeflow

# Check pod status
kubectl get pods -n kubeflow | grep -v Running

# Check events
kubectl get events -n kubeflow --sort-by='.lastTimestamp' | tail -20
```

### Why This Happens

Kustomize generates ConfigMaps with hash suffixes before namespaces are created. The retry mechanism (configured with 10 retries) handles this automatically.

### Quick Fix

**Option 1: Use ArgoCD UI**
1. Go to ArgoCD UI
2. Find the `kubeflow` application
3. Click **Sync** → **Synchronize**
4. Wait (it will retry automatically)

**Option 2: Use CLI**
```bash
argocd app sync kubeflow
```

**Option 3: Pre-create Namespaces**
```bash
kubectl create namespace kubeflow
kubectl create namespace auth
kubectl create namespace oauth2-proxy
kubectl create namespace knative-serving

# Then sync
argocd app sync kubeflow
```

## 📋 Prerequisites

Before deploying, ensure you have:

- ✅ Kubernetes cluster (v1.28+)
- ✅ ArgoCD installed
- ✅ cert-manager installed
- ✅ Istio installed (v1.20+)
- ✅ Longhorn or StorageClass configured
- ✅ `argocd` CLI installed (optional, for CLI commands)

## 🚀 Step-by-Step Deployment

### Step 1: Update Repository URL

Edit `argocd-application.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/manifests.git  # Change this
    targetRevision: main  # Your branch
    path: kubeflow-all-in-one
```

### Step 2: Apply the Application

```bash
kubectl apply -f argocd-application.yaml
```

### Step 3: Verify Application Created

```bash
# Check application exists
kubectl get application kubeflow -n argocd

# Or with ArgoCD CLI
argocd app get kubeflow
```

### Step 4: Sync the Application

**Via UI:**
1. Open ArgoCD UI
2. Find `kubeflow` application
3. Click **Sync**
4. Click **Synchronize**

**Via CLI:**
```bash
argocd app sync kubeflow
```

### Step 5: Monitor Deployment

```bash
# Watch application status
argocd app get kubeflow --watch

# Watch pods
watch kubectl get pods -n kubeflow

# Check all namespaces
kubectl get pods -A | grep -E "kubeflow|auth|oauth2|knative"
```

### Step 6: Wait for Completion

Initial deployment takes 10-15 minutes. You'll know it's done when:

```bash
# All pods are Running
kubectl get pods -n kubeflow | grep -v Running | grep -v Completed
# (Should show only header)

# Application is synced and healthy
argocd app get kubeflow | grep -E "Sync Status|Health Status"
# Should show: Synced, Healthy
```

## 🔍 Verify Deployment

```bash
# Check critical namespaces
kubectl get pods -n kubeflow
kubectl get pods -n auth
kubectl get pods -n oauth2-proxy
kubectl get pods -n knative-serving

# Check Istio resources
kubectl get gateway,virtualservice -n kubeflow

# Check certificates
kubectl get certificate -A
```

## 🌐 Access Kubeflow

### Port Forward (Development)

```bash
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
```

Open: http://localhost:8080

### Production Access

```bash
# Get LoadBalancer IP
kubectl get svc istio-ingressgateway -n istio-system

# Configure DNS to point to this IP
# Then access: https://your-domain.com
```

**Default Credentials:**
- Email: `user@example.com`
- Password: `12341234`

⚠️ **CHANGE THE PASSWORD!** See README.md for instructions.

## 🔧 Customization

### Change Domain

Edit `kustomization.yaml` and add:

```yaml
patches:
- target:
    kind: Gateway
    name: kubeflow-gateway
  patch: |-
    - op: replace
      path: /spec/servers/0/hosts/0
      value: kubeflow.yourdomain.com
    - op: replace
      path: /spec/servers/1/hosts/0
      value: kubeflow.yourdomain.com
```

Commit and push. ArgoCD will auto-sync (if enabled).

### Enable/Disable Components

Edit `kustomization.yaml`:

```yaml
resources:
# Comment out components you don't need
# - ../applications/katib/upstream/installs/katib-with-kubeflow
# - ../applications/spark/spark-operator/overlays/kubeflow
```

### Enable Auto-Sync

After successful initial deployment:

```bash
argocd app set kubeflow --sync-policy automated --auto-prune --self-heal
```

Or edit the application YAML:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

## 🐛 Troubleshooting

### Application Stuck in "OutOfSync"

```bash
# Force sync
argocd app sync kubeflow --force

# Or delete and recreate
kubectl delete application kubeflow -n argocd
kubectl apply -f argocd-application.yaml
argocd app sync kubeflow
```

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n kubeflow

# Check events
kubectl get events -n kubeflow --sort-by='.lastTimestamp'

# Restart deployment
kubectl rollout restart deployment/<deployment-name> -n kubeflow
```

### Certificate Issues

```bash
# Check certificates
kubectl get certificate -A

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Force certificate renewal
kubectl delete certificate <cert-name> -n <namespace>
```

### More Help

See **[ARGOCD-TROUBLESHOOTING.md](ARGOCD-TROUBLESHOOTING.md)** for detailed troubleshooting.

## 📊 Monitoring

### Check Sync Status

```bash
# Application status
argocd app get kubeflow

# Sync history
argocd app history kubeflow

# Resource status
argocd app resources kubeflow
```

### Check Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n kubeflow

# ArgoCD resources
kubectl top pods -n argocd
```

## 🔄 Updates and Upgrades

### Update Kubeflow

1. Update your Git repository (pull latest changes)
2. Commit and push
3. ArgoCD will auto-sync (if enabled) or manually sync:

```bash
argocd app sync kubeflow
```

### Rollback

```bash
# View history
argocd app history kubeflow

# Rollback to previous version
argocd app rollback kubeflow <revision-number>
```

## 🗑️ Uninstall

### Via ArgoCD

```bash
# Delete application (removes all resources)
kubectl delete application kubeflow -n argocd
```

### Manual Cleanup

```bash
# If ArgoCD doesn't clean up everything
kubectl delete namespace kubeflow auth oauth2-proxy knative-serving

# Clean up PVCs (WARNING: Deletes data!)
kubectl delete pvc --all -n kubeflow
```

## 💡 Pro Tips

1. **Use Git for Everything**
   - All changes should go through Git
   - Never edit resources directly in the cluster
   - Let ArgoCD manage the state

2. **Enable Notifications**
   - Configure ArgoCD notifications for Slack/email
   - Get alerted when sync fails

3. **Use App of Apps Pattern**
   - Create separate applications for different components
   - Better control and isolation

4. **Monitor ArgoCD Health**
   ```bash
   kubectl get pods -n argocd
   kubectl top pods -n argocd
   ```

5. **Regular Backups**
   ```bash
   # Backup ArgoCD applications
   kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml
   
   # Backup Kubeflow PVCs
   kubectl get pvc -n kubeflow -o yaml > kubeflow-pvcs-backup.yaml
   ```

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[ARGOCD-QUICKSTART.md](ARGOCD-QUICKSTART.md)** | This file - Quick start |
| **[ARGOCD-TROUBLESHOOTING.md](ARGOCD-TROUBLESHOOTING.md)** | Detailed troubleshooting |
| **[README.md](README.md)** | Main documentation |
| **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** | Complete deployment guide |
| **[CUSTOMIZATION.md](CUSTOMIZATION.md)** | Customization options |

## 🆘 Need Help?

1. **Check logs:**
   ```bash
   kubectl logs -n argocd deployment/argocd-application-controller
   ```

2. **Check troubleshooting guide:**
   See [ARGOCD-TROUBLESHOOTING.md](ARGOCD-TROUBLESHOOTING.md)

3. **Ask the community:**
   - ArgoCD Slack: #argo-cd on CNCF Slack
   - Kubeflow Slack: #kubeflow-platform on CNCF Slack

## ✅ Success Checklist

After deployment, verify:

- [ ] ArgoCD application shows "Synced" and "Healthy"
- [ ] All pods in `kubeflow` namespace are Running
- [ ] All pods in `auth` namespace are Running
- [ ] All pods in `oauth2-proxy` namespace are Running
- [ ] Can access Kubeflow UI (via port-forward or domain)
- [ ] Can log in with default credentials
- [ ] Central Dashboard loads successfully
- [ ] Can create a notebook server

## 🎉 You're Done!

Your Kubeflow platform is now deployed and managed by ArgoCD!

**Next Steps:**
1. Change default password (see README.md)
2. Configure identity provider (optional)
3. Create user profiles
4. Start building ML workflows!

Happy ML Engineering! 🚀

