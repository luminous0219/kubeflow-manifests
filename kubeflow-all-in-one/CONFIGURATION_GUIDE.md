# Kubeflow Configuration Guide for Existing Infrastructure

This guide helps you configure Kubeflow to work with your existing cert-manager, Istio, and Longhorn installations.

## Prerequisites Check

Before proceeding, verify your existing infrastructure:

### 1. Check Longhorn Storage Class
```bash
kubectl get storageclass
```
Note the name of your Longhorn storage class (e.g., `longhorn`, `longhorn-retain`, etc.)

### 2. Check Cert-Manager ClusterIssuer
```bash
kubectl get clusterissuer
```
Note the name of your ClusterIssuer (e.g., `letsencrypt-prod`, `selfsigned-issuer`, etc.)

### 3. Check Istio Ingress Gateway
```bash
kubectl get pods -n istio-system -l istio=ingressgateway
kubectl get svc -n istio-system -l istio=ingressgateway
```
Verify that your Istio ingress gateway is running and has the label `istio: ingressgateway`

## Configuration Steps

### Step 1: Configure Storage Class

If your Longhorn storage class is NOT named `longhorn`, you need to patch the PVCs.

Create a patch file: `kubeflow-all-in-one/patches/storageclass-patch.yaml`

```yaml
# Patch for Katib DB PVC
- op: replace
  path: /spec/storageClassName
  value: YOUR_STORAGE_CLASS_NAME  # e.g., longhorn-retain

---
# Add more patches for other PVCs as needed
```

Then add to `kustomization.yaml`:
```yaml
patches:
- path: patches/storageclass-patch.yaml
  target:
    kind: PersistentVolumeClaim
```

### Step 2: Configure Cert-Manager Integration

The admission webhook and other components use cert-manager. By default, they create self-signed certificates.

If you want to use your ClusterIssuer, you'll need to patch the Certificate resources.

**Note**: For internal services, self-signed certificates (default) are usually fine. Only change this if you have specific requirements.

### Step 3: Verify Istio Gateway Configuration

The Kubeflow Gateway is configured in `common/istio/kubeflow-istio-resources/base/kf-istio-resources.yaml`:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: kubeflow-gateway
spec:
  selector:
    istio: ingressgateway  # This should match your Istio ingress gateway labels
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
```

**Check your Istio ingress gateway labels**:
```bash
kubectl get deployment -n istio-system istio-ingressgateway -o jsonpath='{.spec.template.metadata.labels}' | jq
```

If your ingress gateway uses different labels, you need to patch the Gateway selector.

### Step 4: Configure Domain (Optional)

To use a specific domain instead of wildcard:

1. Edit `common/istio/kubeflow-istio-resources/base/kf-istio-resources.yaml`
2. Change `hosts: ["*"]` to `hosts: ["kubeflow.yourdomain.com"]`

Or add a patch in `kustomization.yaml`:
```yaml
patches:
- target:
    kind: Gateway
    name: kubeflow-gateway
  patch: |-
    - op: replace
      path: /spec/servers/0/hosts/0
      value: kubeflow.yourdomain.com
```

## Common Issues and Solutions

### Issue 1: CRDs Not Found

**Error**: `resource mapping not found for name: "xxx" ... no matches for kind "ClusterTrainingRuntime"`

**Solution**: This is already fixed in the latest kustomization.yaml with proper sync waves. CRDs are deployed in wave 2, custom resources in wave 9.

### Issue 2: CRD Annotation Too Long

**Error**: `metadata.annotations: Too long: may not be more than 262144 bytes`

**Solution**: This is already fixed by removing `buildMetadata: [originAnnotations]` from kustomization.yaml.

### Issue 3: Namespace Missing for ConfigMap

**Error**: `Namespace for default-install-config-xxx /v1, Kind=ConfigMap is missing`

**Solution**: This is already fixed by adding `namespace: kubeflow` to `common/user-namespace/base/kustomization.yaml`.

### Issue 4: Gateway Selector Mismatch

**Error**: VirtualServices not routing traffic correctly

**Solution**: Verify your Istio ingress gateway labels match the Gateway selector:
```bash
# Check gateway labels
kubectl get deployment -n istio-system -l app=istio-ingressgateway -o jsonpath='{.items[0].spec.template.metadata.labels}' | jq

# The Gateway selector should match these labels
```

## Deployment Order (Sync Waves)

The kustomization uses ArgoCD sync waves to ensure proper deployment order:

- **Wave 1**: Namespaces
- **Wave 2**: CRDs, ClusterRoles, ClusterRoleBindings
- **Wave 3**: ServiceAccounts, Secrets, ConfigMaps
- **Wave 4**: Services, PVCs
- **Wave 5**: Istio resources (Gateways, VirtualServices, AuthorizationPolicies)
- **Wave 6**: StatefulSets (databases)
- **Wave 7**: Deployments (applications)
- **Wave 8**: Webhooks
- **Wave 9**: Custom Resources (Profiles, ClusterTrainingRuntimes, ClusterServingRuntimes)

## Verification

After deployment, verify all components:

```bash
# Check all namespaces
kubectl get ns | grep -E "(kubeflow|auth|knative)"

# Check Kubeflow pods
kubectl get pods -n kubeflow

# Check auth components
kubectl get pods -n auth

# Check Knative
kubectl get pods -n knative-serving

# Check Gateway
kubectl get gateway -n kubeflow

# Check VirtualServices
kubectl get virtualservice -n kubeflow
```

## Troubleshooting

### View ArgoCD Application Status
```bash
kubectl get application kubeflow -n argocd
kubectl describe application kubeflow -n argocd
```

### View Sync Errors
```bash
kubectl get application kubeflow -n argocd -o yaml | grep -A 20 "conditions:"
```

### Force Refresh
```bash
# Delete and recreate application
kubectl delete application kubeflow -n argocd
kubectl apply -f kubeflow-all-in-one/argocd-application.yaml
```

### Check CRD Installation
```bash
# List all Kubeflow CRDs
kubectl get crd | grep -E "(kubeflow|kserve|trainer|knative)"

# Check specific CRD
kubectl get crd clustertrainingruntimes.trainer.kubeflow.org
```

## Next Steps

1. Verify your infrastructure prerequisites
2. Apply any necessary patches for storage class or gateway selectors
3. Commit changes to your git repository
4. Create/update the ArgoCD application
5. Monitor the deployment through sync waves
6. Verify all components are healthy

## Support

For issues:
- Check ArgoCD application status and logs
- Review the sync wave order
- Verify CRDs are installed before custom resources
- Check that all required infrastructure (cert-manager, Istio, Longhorn) is healthy

