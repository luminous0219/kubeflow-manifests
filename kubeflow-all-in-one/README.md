# Kubeflow All-in-One Deployment

This directory contains an all-in-one configuration for deploying Kubeflow on Kubernetes clusters that already have **cert-manager**, **Istio**, and **Longhorn** installed.

## 📋 Prerequisites

Before deploying Kubeflow, ensure you have the following already installed in your cluster:

### Required Infrastructure

1. **Kubernetes Cluster** (v1.28+)
   - Minimum 16GB RAM and 8 CPU cores recommended
   - 65GB+ storage available

2. **cert-manager** (v1.10+)
   - A ClusterIssuer configured (e.g., `letsencrypt-prod`)
   - Verify: `kubectl get clusterissuer`

3. **Istio** (v1.20+)
   - Istio with CNI installed
   - Istio ingress gateway available
   - Verify: `kubectl get pods -n istio-system`

4. **Longhorn** (v1.5+)
   - StorageClass configured (e.g., `longhorn` or `longhorn-retain`)
   - Verify: `kubectl get storageclass`

5. **ArgoCD** (for GitOps deployment)
   - ArgoCD installed and accessible
   - Verify: `kubectl get pods -n argocd`

### Required Tools

- `kubectl` (v1.28+)
- `kustomize` (v5.4.3+)
- `git`

## 🚀 Quick Start

### Option 1: Deploy with ArgoCD (Recommended)

This is the easiest way to deploy Kubeflow using GitOps.

#### Step 1: Fork or Clone the Repository

```bash
# Clone the kubeflow-manifests repository
git clone https://github.com/kubeflow/manifests.git
cd manifests
```

#### Step 2: Customize Configuration (Optional)

Edit `kubeflow-all-in-one/kustomization.yaml` to customize your deployment:

```yaml
# Choose OAuth2-Proxy mode based on your cluster
# - m2m-dex-only: Most clusters (default)
# - m2m-dex-and-kind: KIND/K3D/Rancher/GKE
# - m2m-dex-and-eks: AWS EKS

# Choose Pipeline storage
# - SeaweedFS (default, lightweight S3-compatible)
# - MinIO (alternative)

# Choose Pipeline definitions storage
# - Database (MySQL, default)
# - Kubernetes native (CRDs)
```

#### Step 3: Update ArgoCD Application

Edit `kubeflow-all-in-one/argocd-application.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/manifests.git  # Your fork
    targetRevision: main  # Your branch
```

#### Step 4: Apply ArgoCD Application

```bash
kubectl apply -f kubeflow-all-in-one/argocd-application.yaml
```

#### Step 5: Monitor Deployment

```bash
# Watch ArgoCD sync status
kubectl get application -n argocd kubeflow

# Watch pods coming up
watch kubectl get pods -n kubeflow
watch kubectl get pods -n auth
watch kubectl get pods -n oauth2-proxy
watch kubectl get pods -n knative-serving
```

### Option 2: Deploy with Kustomize

If you prefer direct deployment without ArgoCD:

```bash
cd manifests

# Build and apply (may need to run multiple times)
while ! kustomize build kubeflow-all-in-one | kubectl apply --server-side --force-conflicts -f -; do 
  echo "Retrying to apply resources"; 
  sleep 20; 
done
```

## 🔧 Configuration

### Customize Domain

To use your own domain, create a patch file:

```bash
cat > kubeflow-all-in-one/domain-patch.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- kustomization.yaml

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
EOF

# Apply with custom domain
kustomize build kubeflow-all-in-one/domain-patch.yaml | kubectl apply -f -
```

### Change Default Password

**IMPORTANT**: Change the default password before deploying to production!

1. Generate a new password hash:

```bash
python3 -c 'from passlib.hash import bcrypt; import getpass; print(bcrypt.using(rounds=12, ident="2y").hash(getpass.getpass()))'
```

2. Update the password in `common/dex/base/dex-passwords.yaml`:

```yaml
stringData:
  DEX_USER_PASSWORD: YOUR_GENERATED_HASH
```

Or update after deployment:

```bash
# Delete existing secret
kubectl delete secret dex-passwords -n auth

# Create new secret with your hash
kubectl create secret generic dex-passwords \
  --from-literal=DEX_USER_PASSWORD='YOUR_HASH' \
  -n auth

# Restart Dex
kubectl delete pods --all -n auth
```

### Configure Identity Provider

To use your own identity provider (Azure AD, Google, GitHub, etc.), edit `common/dex/overlays/oauth2-proxy/config-map.yaml`:

```yaml
connectors:
- type: oidc
  id: azure
  name: Azure AD
  config:
    issuer: https://login.microsoftonline.com/TENANT_ID/v2.0
    clientID: YOUR_CLIENT_ID
    clientSecret: YOUR_CLIENT_SECRET
    redirectURI: https://kubeflow.yourdomain.com/dex/callback
    scopes:
      - openid
      - profile
      - email
```

## 📦 What Gets Deployed

This all-in-one deployment includes:

### Authentication & Authorization
- ✅ **Dex** - OpenID Connect identity provider
- ✅ **OAuth2-Proxy** - Authentication proxy with Istio integration
- ✅ **Profiles + KFAM** - Multi-user namespace management

### Core Components
- ✅ **Central Dashboard** - Unified web interface
- ✅ **Kubeflow Pipelines** - ML workflow orchestration
- ✅ **Jupyter Notebooks** - Interactive development environment
- ✅ **Katib** - Hyperparameter tuning and AutoML
- ✅ **KServe** - Model serving and inference
- ✅ **Training Operator** - Distributed training (TensorFlow, PyTorch, etc.)

### Supporting Services
- ✅ **Volumes Web App** - PVC management
- ✅ **Tensorboard** - Training visualization
- ✅ **PVC Viewer** - Volume inspection
- ✅ **Spark Operator** - Big data processing
- ✅ **SeaweedFS** - S3-compatible object storage for artifacts

### Infrastructure
- ✅ **Knative Serving** - Serverless workloads (for KServe)
- ✅ **Network Policies** - Security and traffic control
- ✅ **Pod Security Standards** - Enhanced security

### Optional Components
- ⚪ **Model Registry** - ML model versioning (disabled by default)
- ⚪ **Knative Eventing** - Event-driven architecture (disabled by default)

## 🌐 Access Kubeflow

### Port Forward (Development)

```bash
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
```

Then access: http://localhost:8080

### Production Access

For production, expose Kubeflow through your Istio ingress gateway with proper TLS:

1. **Ensure your domain DNS points to the Istio ingress gateway LoadBalancer IP**

```bash
# Get the LoadBalancer IP
kubectl get svc istio-ingressgateway -n istio-system
```

2. **Create or update the Istio Gateway**

The gateway is created automatically, but verify it's configured correctly:

```bash
kubectl get gateway kubeflow-gateway -n kubeflow
```

3. **Verify TLS certificate**

```bash
kubectl get certificate -n istio-system
```

4. **Access Kubeflow**

Navigate to: `https://kubeflow.yourdomain.com`

Default credentials:
- **Email**: `user@example.com`
- **Password**: `12341234` (CHANGE THIS!)

## 🔍 Verification

### Check All Pods are Running

```bash
# Kubeflow components
kubectl get pods -n kubeflow

# Authentication
kubectl get pods -n auth
kubectl get pods -n oauth2-proxy

# Knative
kubectl get pods -n knative-serving

# Check for any issues
kubectl get pods -A | grep -v Running | grep -v Completed
```

### Verify Services

```bash
# Check all services are created
kubectl get svc -n kubeflow

# Check Istio virtual services
kubectl get virtualservices -n kubeflow

# Check gateways
kubectl get gateways -n kubeflow
```

### Test Pipeline Access

```bash
# Port forward to test
kubectl port-forward svc/ml-pipeline-ui -n kubeflow 8080:80

# Access at http://localhost:8080
```

## 🛠️ Troubleshooting

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod POD_NAME -n NAMESPACE

# Check logs
kubectl logs POD_NAME -n NAMESPACE

# Check previous logs if pod crashed
kubectl logs POD_NAME -n NAMESPACE --previous
```

### Certificate Issues

```bash
# Check certificate status
kubectl get certificate -A
kubectl describe certificate CERT_NAME -n NAMESPACE

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Verify ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### Authentication Issues

```bash
# Check Dex logs
kubectl logs -n auth deployment/dex

# Check OAuth2-Proxy logs
kubectl logs -n oauth2-proxy deployment/oauth2-proxy

# Verify secrets
kubectl get secrets -n auth
kubectl get secrets -n oauth2-proxy
```

### Storage Issues

```bash
# Check PVCs
kubectl get pvc -n kubeflow

# Check Longhorn volumes
kubectl get volumes -n longhorn-system

# Check StorageClass
kubectl get storageclass
```

### Istio Issues

```bash
# Check Istio configuration
istioctl analyze -n kubeflow

# Check proxy status
istioctl proxy-status

# Check virtual services
kubectl get virtualservices -n kubeflow -o yaml
```

### Pipeline Issues

```bash
# Check pipeline components
kubectl get pods -n kubeflow | grep ml-pipeline

# Check Argo workflows
kubectl get workflows -n kubeflow

# Check MinIO/SeaweedFS
kubectl get pods -n kubeflow | grep -E "minio|seaweedfs"
```

### Common Errors

#### Error: "CRD not ready"

This is normal on first install. The solution is to retry:

```bash
# Wait a bit and retry
sleep 30
kustomize build kubeflow-all-in-one | kubectl apply -f -
```

#### Error: "Webhook connection refused"

Wait for webhook pods to be ready:

```bash
kubectl wait --for=condition=Ready pod -l app=webhook --timeout=180s -n NAMESPACE
```

#### Error: "ImagePullBackOff"

Check image pull secrets and network connectivity:

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

## 🔄 Upgrading

To upgrade Kubeflow:

1. **Backup your data**

```bash
# Backup PVCs, configs, etc.
kubectl get pvc -n kubeflow -o yaml > kubeflow-pvcs-backup.yaml
```

2. **Update the manifests**

```bash
cd manifests
git pull origin master
```

3. **Apply updates**

```bash
# With ArgoCD (automatic)
kubectl get application -n argocd kubeflow

# Or with kustomize
kustomize build kubeflow-all-in-one | kubectl apply -f -
```

## 🗑️ Uninstalling

### With ArgoCD

```bash
kubectl delete application kubeflow -n argocd
```

### With Kustomize

```bash
kustomize build kubeflow-all-in-one | kubectl delete -f -
```

### Clean up PVCs (Optional)

```bash
# WARNING: This will delete all data!
kubectl delete pvc --all -n kubeflow
kubectl delete pvc --all -n auth
```

## 📊 Resource Requirements

Based on the official Kubeflow documentation:

| Component | CPU (millicores) | Memory (Mi) | Storage (GB) |
|-----------|------------------|-------------|--------------|
| Pipelines | 970m | 3552Mi | 35GB |
| KServe | 600m | 1200Mi | 0GB |
| Knative | 1450m | 1038Mi | 0GB |
| Katib | 13m | 476Mi | 10GB |
| Model Registry* | 510m | 2112Mi | 20GB |
| Other Components | ~1337m | ~4963Mi | 0GB |
| **Total (without Model Registry)** | **~4380m** | **~12341Mi** | **~65GB** |

*Model Registry is disabled by default

## 🔐 Security Considerations

1. **Change default passwords** before production use
2. **Configure proper RBAC** for users
3. **Enable Pod Security Standards** (included by default)
4. **Use TLS certificates** from a trusted CA
5. **Configure network policies** (included by default)
6. **Regular security updates** - keep components up to date
7. **Use secrets management** - consider external secret stores

## 📚 Additional Resources

- [Kubeflow Documentation](https://www.kubeflow.org/docs/)
- [Kubeflow Manifests Repository](https://github.com/kubeflow/manifests)
- [Kubeflow Community](https://www.kubeflow.org/docs/about/community/)
- [Kubeflow Slack](https://app.slack.com/client/T08PSQ7BQ/C073W572LA2)

## 🤝 Contributing

This all-in-one deployment is based on the official Kubeflow manifests. For issues or contributions:

1. Check the [Kubeflow Manifests Issues](https://github.com/kubeflow/manifests/issues)
2. Join the [Kubeflow Community](https://www.kubeflow.org/docs/about/community/)
3. Contribute to the [upstream repository](https://github.com/kubeflow/manifests)

## 📝 License

This deployment configuration follows the same license as the Kubeflow project (Apache 2.0).

## ⚠️ Important Notes

1. **This is for clusters with existing infrastructure** - cert-manager, Istio, and Longhorn must be pre-installed
2. **Default credentials are insecure** - change them before production use
3. **First deployment may require multiple retries** - this is normal due to CRD dependencies
4. **Resource requirements are significant** - ensure your cluster has sufficient capacity
5. **Backup your data** - especially PVCs before upgrades or changes

## 🎯 Next Steps

After successful deployment:

1. **Change default password** (see Configuration section)
2. **Create user profiles** for your team
3. **Configure identity provider** (optional but recommended)
4. **Set up monitoring** with Prometheus/Grafana
5. **Configure backup strategy** for persistent volumes
6. **Review and adjust resource limits** based on your workload
7. **Set up CI/CD pipelines** for ML workflows

Happy ML Engineering! 🚀

