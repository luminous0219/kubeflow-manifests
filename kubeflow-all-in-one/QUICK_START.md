# Quick Start - Kubeflow Deployment with ArgoCD

## Your Current Infrastructure ✓

Based on your cluster, the following is already configured:

- **Storage Class**: `longhorn` (default) ✓
- **Cert-Manager Issuer**: `letsencrypt-prod` and `selfsigned-issuer` ✓
- **Istio Gateway**: Labels match (`istio: ingressgateway`) ✓

## Fixes Applied

The following issues have been fixed in the kustomization:

1. ✅ **ConfigMap Namespace Issue**: Added `namespace: kubeflow` to user-namespace kustomization
2. ✅ **CRD Annotation Size**: Removed `buildMetadata: [originAnnotations]` to prevent annotation overflow
3. ✅ **CRD Ordering**: Added sync wave annotations to ensure CRDs (wave 2) deploy before custom resources (wave 9)
4. ✅ **Sync Options**: Updated ArgoCD application with proper sync options

## Deploy Kubeflow

### Option 1: Fresh Deployment

```bash
# Apply the ArgoCD application
kubectl apply -f /home/ml/kubeflow-manifests/kubeflow-all-in-one/argocd-application.yaml

# Watch the deployment
watch kubectl get application kubeflow -n argocd
```

### Option 2: Refresh Existing Deployment

```bash
# Delete and recreate (recommended after fixes)
kubectl delete application kubeflow -n argocd
kubectl apply -f /home/ml/kubeflow-manifests/kubeflow-all-in-one/argocd-application.yaml
```

### Option 3: Manual Sync via ArgoCD UI

1. Access ArgoCD UI
2. Find the `kubeflow` application
3. Click "Sync" → "Synchronize"
4. Watch the sync waves progress (1 → 9)

## Monitor Deployment

### Check Application Status
```bash
# Overall status
kubectl get application kubeflow -n argocd

# Detailed status
kubectl describe application kubeflow -n argocd

# Check for errors
kubectl get application kubeflow -n argocd -o yaml | grep -A 20 "conditions:"
```

### Watch Pods Coming Up

```bash
# Kubeflow namespace
watch kubectl get pods -n kubeflow

# Auth namespace
watch kubectl get pods -n auth

# Knative Serving
watch kubectl get pods -n knative-serving
```

### Check Sync Waves Progress

The deployment happens in waves. You should see resources being created in this order:

1. **Wave 1**: Namespaces (kubeflow, auth, knative-serving)
2. **Wave 2**: CRDs (CustomResourceDefinitions)
3. **Wave 3**: ConfigMaps, Secrets, ServiceAccounts
4. **Wave 4**: Services, PVCs
5. **Wave 5**: Istio resources (Gateways, VirtualServices)
6. **Wave 6**: StatefulSets (databases)
7. **Wave 7**: Deployments (applications)
8. **Wave 8**: Webhooks
9. **Wave 9**: Custom Resources (Profiles, Runtimes)

## Expected Timeline

- **Wave 1-3**: ~30 seconds
- **Wave 4-5**: ~1 minute
- **Wave 6**: ~2-5 minutes (databases starting)
- **Wave 7**: ~5-10 minutes (applications starting)
- **Wave 8-9**: ~1-2 minutes

**Total**: ~10-20 minutes for full deployment

## Verify Deployment

### Check CRDs
```bash
kubectl get crd | grep -E "(kubeflow|kserve|trainer|knative)"
```

### Check Gateways
```bash
kubectl get gateway -n kubeflow
kubectl get gateway -n knative-serving
```

### Check VirtualServices
```bash
kubectl get virtualservice -n kubeflow
```

### Check Core Components
```bash
# Central Dashboard
kubectl get deployment centraldashboard -n kubeflow

# Profiles Controller
kubectl get deployment profiles-deployment -n kubeflow

# Jupyter Web App
kubectl get deployment jupyter-web-app-deployment -n kubeflow

# Katib
kubectl get deployment katib-controller -n kubeflow
kubectl get deployment katib-ui -n kubeflow

# KServe
kubectl get deployment kserve-controller-manager -n kubeflow

# Training Operator
kubectl get deployment training-operator -n kubeflow-system
```

## Access Kubeflow

### Get Ingress Gateway Address
```bash
kubectl get svc istio-ingressgateway -n istio-system
```

### Access via Port Forward (for testing)
```bash
# Port forward to istio ingress gateway
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80

# Access at: http://localhost:8080
```

### Default Credentials
- **Email**: `user@example.com`
- **Password**: `12341234`

## Troubleshooting

### Sync Failed - CRD Not Found

If you see errors like:
```
no matches for kind "ClusterTrainingRuntime" in version "trainer.kubeflow.org/v1alpha1"
```

**Solution**: The sync waves should handle this automatically. If it persists:
1. Check that CRDs are installed: `kubectl get crd | grep trainer`
2. Wait for wave 2 to complete before wave 9
3. Manually sync again after CRDs are established

### Sync Failed - Annotation Too Long

If you see:
```
metadata.annotations: Too long: may not be more than 262144 bytes
```

**Solution**: Already fixed by removing `buildMetadata: [originAnnotations]`. Make sure you're using the latest commit.

### Pods Stuck in Pending

Check PVC status:
```bash
kubectl get pvc -n kubeflow
```

If PVCs are pending, verify Longhorn is healthy:
```bash
kubectl get pods -n longhorn-system
```

### Webhooks Failing

Webhooks need cert-manager to generate certificates. Check:
```bash
kubectl get certificate -n kubeflow
kubectl get certificate -n knative-serving
```

## Clean Up (if needed)

### Delete Kubeflow Application
```bash
kubectl delete application kubeflow -n argocd
```

### Delete Namespaces (WARNING: This deletes all data)
```bash
kubectl delete ns kubeflow auth knative-serving knative-eventing
```

## Next Steps

1. Access Kubeflow Dashboard
2. Create a new Profile (namespace) for your team
3. Launch a Jupyter Notebook
4. Try a sample pipeline
5. Train a model with the Training Operator

## Support

For issues, check:
- ArgoCD application logs
- Pod logs: `kubectl logs -n kubeflow <pod-name>`
- Events: `kubectl get events -n kubeflow --sort-by='.lastTimestamp'`
- Configuration guide: `CONFIGURATION_GUIDE.md`

