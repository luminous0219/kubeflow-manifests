# Kubeflow All-in-One Deployment Guide

This guide walks you through deploying Kubeflow using the all-in-one configuration with ArgoCD.

## 📋 Quick Reference

| Method | Best For | Complexity | Time to Deploy |
|--------|----------|------------|----------------|
| ArgoCD | Production, GitOps | Low | 10-15 min |
| Kustomize | Development, Testing | Medium | 5-10 min |
| Helm | Custom deployments | Medium | 5-10 min |
| Install Script | Quick testing | Low | 5-10 min |

## 🚀 Method 1: Deploy with ArgoCD (Recommended)

### Prerequisites Checklist

- [ ] Kubernetes cluster (v1.28+) with 16GB RAM, 8 CPU cores
- [ ] cert-manager installed with ClusterIssuer configured
- [ ] Istio installed (v1.20+) with CNI
- [ ] Longhorn or another StorageClass available
- [ ] ArgoCD installed and accessible
- [ ] kubectl and kustomize installed locally
- [ ] Git repository access (fork or clone kubeflow/manifests)

### Step-by-Step Deployment

#### 1. Prepare Your Repository

```bash
# Option A: Fork the repository (recommended for production)
# Go to https://github.com/kubeflow/manifests and click Fork

# Option B: Clone directly (for testing)
git clone https://github.com/kubeflow/manifests.git
cd manifests
```

#### 2. Customize Configuration (Optional)

Edit `kubeflow-all-in-one/kustomization.yaml`:

```yaml
# Choose your OAuth2-Proxy mode
# - m2m-dex-only: Most clusters (default)
# - m2m-dex-and-kind: KIND/K3D/Rancher/GKE
# - m2m-dex-and-eks: AWS EKS

# Choose pipeline storage backend
# - SeaweedFS (default, lightweight)
# - MinIO (alternative)

# Choose pipeline definitions storage
# - Database (MySQL, default)
# - Kubernetes native (CRDs)
```

To customize domain and other settings, create a patch:

```bash
cat > kubeflow-all-in-one/custom-patch.yaml <<EOF
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
```

#### 3. Update ArgoCD Application Manifest

Edit `kubeflow-all-in-one/argocd-application.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR_USERNAME/manifests.git  # Your repository
    targetRevision: main  # Your branch
    path: kubeflow-all-in-one  # Or kubeflow-all-in-one/custom-patch.yaml
```

#### 4. Deploy to ArgoCD

```bash
# Apply the ArgoCD application
kubectl apply -f kubeflow-all-in-one/argocd-application.yaml

# Verify application is created
kubectl get application -n argocd kubeflow

# Watch the sync progress
kubectl get application -n argocd kubeflow -w
```

#### 5. Monitor Deployment

```bash
# Watch ArgoCD application status
argocd app get kubeflow

# Watch pods coming up
watch kubectl get pods -n kubeflow

# Check all namespaces
kubectl get pods -A | grep -E "kubeflow|auth|oauth2-proxy|knative"
```

#### 6. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n kubeflow
kubectl get pods -n auth
kubectl get pods -n oauth2-proxy
kubectl get pods -n knative-serving

# Check for any issues
kubectl get pods -A | grep -v Running | grep -v Completed

# Verify Istio configuration
kubectl get gateway,virtualservice -n kubeflow

# Check certificates
kubectl get certificate -A
```

#### 7. Access Kubeflow

**Development/Testing (Port Forward):**

```bash
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
```

Then open: http://localhost:8080

**Production (via Domain):**

1. Get your LoadBalancer IP:
   ```bash
   kubectl get svc istio-ingressgateway -n istio-system
   ```

2. Configure DNS to point to the LoadBalancer IP

3. Access: https://kubeflow.yourdomain.com

**Default Credentials:**
- Email: `user@example.com`
- Password: `12341234`

⚠️ **CHANGE THE PASSWORD IMMEDIATELY!**

## 🛠️ Method 2: Deploy with Kustomize

### Quick Deploy

```bash
cd manifests/kubeflow-all-in-one

# Deploy (may need multiple attempts due to CRD dependencies)
while ! kustomize build . | kubectl apply --server-side --force-conflicts -f -; do 
  echo "Retrying to apply resources"; 
  sleep 20; 
done
```

### With Custom Configuration

```bash
# Create custom overlay
mkdir -p my-kubeflow
cd my-kubeflow

cat > kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../kubeflow-all-in-one

patches:
# Add your patches here
- target:
    kind: Gateway
    name: kubeflow-gateway
  patch: |-
    - op: replace
      path: /spec/servers/0/hosts/0
      value: kubeflow.yourdomain.com

commonLabels:
  environment: production
EOF

# Deploy
kustomize build . | kubectl apply --server-side --force-conflicts -f -
```

## 📦 Method 3: Deploy with Helm (Future)

The Helm chart structure is provided but currently wraps Kustomize. For pure Helm deployment:

```bash
cd manifests/kubeflow-all-in-one

# Install with default values
helm install kubeflow . -n kubeflow --create-namespace

# Install with custom values
helm install kubeflow . -n kubeflow --create-namespace -f my-values.yaml

# Upgrade
helm upgrade kubeflow . -n kubeflow -f my-values.yaml
```

## 🚀 Method 4: Deploy with Install Script

The quickest way for testing:

```bash
cd manifests/kubeflow-all-in-one

# Check prerequisites
./install.sh --check-only

# Install
./install.sh

# Check status
./install.sh --status
```

## 🔧 Post-Deployment Configuration

### 1. Change Default Password

**CRITICAL: Do this before allowing user access!**

```bash
# Generate new password hash
python3 -c 'from passlib.hash import bcrypt; import getpass; print(bcrypt.using(rounds=12, ident="2y").hash(getpass.getpass()))'

# Update the secret
kubectl delete secret dex-passwords -n auth
kubectl create secret generic dex-passwords \
  --from-literal=DEX_USER_PASSWORD='YOUR_HASH_HERE' \
  -n auth

# Restart Dex
kubectl rollout restart deployment/dex -n auth
```

### 2. Configure Identity Provider

To use Azure AD, Google, GitHub, or other providers:

1. Edit the Dex ConfigMap:
   ```bash
   kubectl edit configmap dex -n auth
   ```

2. Add connector configuration (see CUSTOMIZATION.md for examples)

3. Restart Dex:
   ```bash
   kubectl rollout restart deployment/dex -n auth
   ```

### 3. Create User Profiles

```bash
# Create a profile for a new user
cat <<EOF | kubectl apply -f -
apiVersion: kubeflow.org/v1
kind: Profile
metadata:
  name: kubeflow-user-newuser-example-com
spec:
  owner:
    kind: User
    name: newuser@example.com
  resourceQuotaSpec:
    hard:
      cpu: "10"
      memory: 20Gi
      persistentvolumeclaims: "10"
      requests.nvidia.com/gpu: "2"
EOF
```

### 4. Configure TLS Certificates

If using Let's Encrypt:

```bash
# Verify ClusterIssuer exists
kubectl get clusterissuer letsencrypt-prod

# Check certificate status
kubectl get certificate -n istio-system

# If certificate is not issuing, check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

### 5. Set Up Monitoring (Optional)

```bash
# Install Prometheus and Grafana (if not already installed)
# Then configure ServiceMonitors for Kubeflow components

kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kubeflow-pipelines
  namespace: kubeflow
spec:
  selector:
    matchLabels:
      app: ml-pipeline
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
EOF
```

## 🔍 Verification Checklist

After deployment, verify:

- [ ] All pods in `kubeflow` namespace are Running
- [ ] All pods in `auth` namespace are Running
- [ ] All pods in `oauth2-proxy` namespace are Running
- [ ] All pods in `knative-serving` namespace are Running (if enabled)
- [ ] Istio Gateway is configured correctly
- [ ] VirtualServices are created
- [ ] TLS certificates are issued
- [ ] Can access Kubeflow UI
- [ ] Can log in with default credentials
- [ ] Central Dashboard loads
- [ ] Can create a notebook server
- [ ] Can access notebook server

## 🐛 Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n kubeflow

# Describe problematic pod
kubectl describe pod <pod-name> -n kubeflow

# Check logs
kubectl logs <pod-name> -n kubeflow

# Check events
kubectl get events -n kubeflow --sort-by='.lastTimestamp'
```

### Authentication Issues

```bash
# Check Dex logs
kubectl logs -n auth deployment/dex

# Check OAuth2-Proxy logs
kubectl logs -n oauth2-proxy deployment/oauth2-proxy

# Verify secrets exist
kubectl get secrets -n auth
kubectl get secrets -n oauth2-proxy

# Check Dex configuration
kubectl get configmap dex -n auth -o yaml
```

### Certificate Issues

```bash
# Check certificate status
kubectl get certificate -A
kubectl describe certificate <cert-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check ClusterIssuer
kubectl describe clusterissuer letsencrypt-prod

# Manual certificate request (for testing)
kubectl delete certificate kubeflow-tls-cert -n istio-system
# Wait for automatic recreation
```

### Pipeline Issues

```bash
# Check pipeline components
kubectl get pods -n kubeflow | grep ml-pipeline

# Check Argo workflows
kubectl get workflows -n kubeflow

# Check storage backend (SeaweedFS/MinIO)
kubectl get pods -n kubeflow | grep -E "seaweedfs|minio"

# Check pipeline API
kubectl logs -n kubeflow deployment/ml-pipeline
```

### Network Issues

```bash
# Check Istio configuration
istioctl analyze -n kubeflow

# Check virtual services
kubectl get virtualservices -n kubeflow -o yaml

# Check destination rules
kubectl get destinationrules -n kubeflow

# Check network policies
kubectl get networkpolicies -n kubeflow
```

### Storage Issues

```bash
# Check PVCs
kubectl get pvc -n kubeflow

# Check PV status
kubectl get pv

# Check Longhorn (if using)
kubectl get volumes -n longhorn-system

# Describe problematic PVC
kubectl describe pvc <pvc-name> -n kubeflow
```

## 📊 Resource Monitoring

### Check Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n kubeflow

# Check resource quotas
kubectl get resourcequota -n kubeflow

# Check limit ranges
kubectl get limitrange -n kubeflow
```

### Adjust Resources

If pods are OOMKilled or CPU throttled, adjust resources:

```bash
# Edit deployment
kubectl edit deployment <deployment-name> -n kubeflow

# Or create a patch (see CUSTOMIZATION.md)
```

## 🔄 Upgrading

### With ArgoCD

ArgoCD will automatically sync when you update your Git repository:

```bash
# Update your repository
git pull origin master

# ArgoCD will detect changes and sync
# Or manually sync
argocd app sync kubeflow
```

### With Kustomize

```bash
cd manifests
git pull origin master

cd kubeflow-all-in-one
kustomize build . | kubectl apply --server-side --force-conflicts -f -
```

### Backup Before Upgrade

```bash
# Backup PVCs
kubectl get pvc -n kubeflow -o yaml > kubeflow-pvcs-backup.yaml

# Backup configurations
kubectl get configmap -n kubeflow -o yaml > kubeflow-configmaps-backup.yaml
kubectl get secret -n kubeflow -o yaml > kubeflow-secrets-backup.yaml

# Backup profiles
kubectl get profiles -o yaml > kubeflow-profiles-backup.yaml
```

## 🗑️ Uninstalling

### With ArgoCD

```bash
# Delete application (this will remove all resources)
kubectl delete application kubeflow -n argocd

# Optionally delete PVCs (WARNING: This deletes all data!)
kubectl delete pvc --all -n kubeflow
```

### With Kustomize

```bash
cd manifests/kubeflow-all-in-one
kustomize build . | kubectl delete -f -

# Optionally delete PVCs
kubectl delete pvc --all -n kubeflow
kubectl delete pvc --all -n auth
```

### Clean Up Namespaces

```bash
# Delete namespaces (this will delete everything)
kubectl delete namespace kubeflow
kubectl delete namespace auth
kubectl delete namespace oauth2-proxy
kubectl delete namespace knative-serving
```

## 📚 Next Steps

After successful deployment:

1. **Security**
   - [ ] Change default password
   - [ ] Configure identity provider
   - [ ] Review RBAC policies
   - [ ] Enable audit logging

2. **User Management**
   - [ ] Create user profiles
   - [ ] Set resource quotas
   - [ ] Configure namespace defaults

3. **Monitoring**
   - [ ] Set up Prometheus/Grafana
   - [ ] Configure alerts
   - [ ] Monitor resource usage

4. **Backup**
   - [ ] Configure PVC backups
   - [ ] Backup configurations
   - [ ] Document recovery procedures

5. **Documentation**
   - [ ] Document custom configurations
   - [ ] Create user guides
   - [ ] Document troubleshooting procedures

## 🆘 Getting Help

- **Documentation**: See README.md and CUSTOMIZATION.md
- **Community**: [Kubeflow Slack](https://app.slack.com/client/T08PSQ7BQ/C073W572LA2)
- **Issues**: [GitHub Issues](https://github.com/kubeflow/manifests/issues)
- **Forum**: [Kubeflow Community](https://www.kubeflow.org/docs/about/community/)

## 📝 Summary

You now have a complete Kubeflow deployment! The all-in-one configuration provides:

✅ Production-ready authentication with Dex and OAuth2-Proxy  
✅ Full Kubeflow platform with all major components  
✅ Integrated with your existing Istio, cert-manager, and Longhorn  
✅ GitOps-ready with ArgoCD support  
✅ Customizable and extensible  

Happy ML Engineering! 🚀

