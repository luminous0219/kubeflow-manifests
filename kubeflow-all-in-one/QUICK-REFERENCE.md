# Kubeflow All-in-One - Quick Reference Card

## 🚀 Quick Deploy

```bash
# ArgoCD (Recommended)
kubectl apply -f argocd-application.yaml

# Kustomize
kustomize build . | kubectl apply --server-side --force-conflicts -f -

# Install Script
./install.sh
```

## 🔑 Default Credentials

```
Email: user@example.com
Password: 12341234
```

⚠️ **CHANGE IMMEDIATELY!**

## 📍 Access Methods

### Port Forward (Dev)
```bash
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
# http://localhost:8080
```

### Production
```bash
# Get LoadBalancer IP
kubectl get svc istio-ingressgateway -n istio-system
# Configure DNS → https://your-domain.com
```

## 🔧 Common Commands

### Check Status
```bash
# All pods
kubectl get pods -A | grep -E "kubeflow|auth|oauth2"

# Specific namespace
kubectl get pods -n kubeflow

# Issues only
kubectl get pods -A | grep -v Running | grep -v Completed
```

### View Logs
```bash
# Central Dashboard
kubectl logs -n kubeflow deployment/centraldashboard

# Dex (Auth)
kubectl logs -n auth deployment/dex

# OAuth2-Proxy
kubectl logs -n oauth2-proxy deployment/oauth2-proxy

# Pipelines
kubectl logs -n kubeflow deployment/ml-pipeline
```

### Restart Components
```bash
# Restart Dex
kubectl rollout restart deployment/dex -n auth

# Restart Dashboard
kubectl rollout restart deployment/centraldashboard -n kubeflow

# Restart all in namespace
kubectl rollout restart deployment -n kubeflow
```

## 🔐 Change Password

```bash
# 1. Generate hash
python3 -c 'from passlib.hash import bcrypt; import getpass; print(bcrypt.using(rounds=12, ident="2y").hash(getpass.getpass()))'

# 2. Update secret
kubectl delete secret dex-passwords -n auth
kubectl create secret generic dex-passwords \
  --from-literal=DEX_USER_PASSWORD='YOUR_HASH' -n auth

# 3. Restart Dex
kubectl rollout restart deployment/dex -n auth
```

## 👤 Create User Profile

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kubeflow.org/v1
kind: Profile
metadata:
  name: kubeflow-user-newuser-example-com
spec:
  owner:
    kind: User
    name: newuser@example.com
EOF
```

## 🔍 Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by='.lastTimestamp'
```

### Auth Issues
```bash
kubectl logs -n auth deployment/dex
kubectl logs -n oauth2-proxy deployment/oauth2-proxy
kubectl get secrets -n auth
```

### Certificate Issues
```bash
kubectl get certificate -A
kubectl describe certificate CERT_NAME -n NAMESPACE
kubectl logs -n cert-manager deployment/cert-manager
```

### Storage Issues
```bash
kubectl get pvc -n kubeflow
kubectl get pv
kubectl describe pvc PVC_NAME -n kubeflow
```

### Network Issues
```bash
istioctl analyze -n kubeflow
kubectl get virtualservices -n kubeflow
kubectl get gateway -n kubeflow
```

## 📊 Resource Monitoring

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n kubeflow

# Specific pod
kubectl top pod POD_NAME -n kubeflow
```

## 🔄 Upgrade

### ArgoCD
```bash
# Auto-syncs on git push
argocd app sync kubeflow
```

### Kustomize
```bash
git pull origin master
kustomize build . | kubectl apply --server-side --force-conflicts -f -
```

## 🗑️ Uninstall

### ArgoCD
```bash
kubectl delete application kubeflow -n argocd
```

### Kustomize
```bash
kustomize build . | kubectl delete -f -
```

### Clean All
```bash
kubectl delete namespace kubeflow auth oauth2-proxy knative-serving
```

## 🔧 Customization Quick Patches

### Change Domain
```yaml
patches:
- target:
    kind: Gateway
    name: kubeflow-gateway
  patch: |-
    - op: replace
      path: /spec/servers/0/hosts/0
      value: new-domain.com
```

### Adjust Resources
```yaml
patches:
- target:
    kind: Deployment
    name: ml-pipeline
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/memory
      value: 4Gi
```

### Change Storage Class
```yaml
patches:
- target:
    kind: PersistentVolumeClaim
  patch: |-
    - op: replace
      path: /spec/storageClassName
      value: my-storage-class
```

## 📦 Component Selection

### Minimal (Dev)
```yaml
# Enable: Dashboard, Profiles, Jupyter
# Disable: Pipelines, Katib, KServe, Trainer
```

### Training Focus
```yaml
# Enable: Jupyter, Katib, Trainer, Tensorboard
# Disable: KServe, Model Registry
```

### Serving Focus
```yaml
# Enable: KServe, Model Registry, Knative
# Disable: Katib, Trainer
```

## 🔐 Identity Providers

### Azure AD
```yaml
connectors:
- type: oidc
  id: azure
  name: Azure AD
  config:
    issuer: https://login.microsoftonline.com/TENANT_ID/v2.0
    clientID: CLIENT_ID
    clientSecret: CLIENT_SECRET
```

### Google
```yaml
connectors:
- type: oidc
  id: google
  name: Google
  config:
    issuer: https://accounts.google.com
    clientID: CLIENT_ID.apps.googleusercontent.com
    clientSecret: CLIENT_SECRET
```

### GitHub
```yaml
connectors:
- type: github
  id: github
  name: GitHub
  config:
    clientID: CLIENT_ID
    clientSecret: CLIENT_SECRET
```

## 📊 Health Checks

```bash
# All critical pods
kubectl get pods -n kubeflow,auth,oauth2-proxy,knative-serving

# Istio config
istioctl analyze -n kubeflow

# Certificates
kubectl get certificate -A

# Storage
kubectl get pvc -A

# Network
kubectl get networkpolicies -n kubeflow
```

## 🆘 Emergency Commands

### Force Restart All
```bash
kubectl rollout restart deployment -n kubeflow
kubectl rollout restart deployment -n auth
kubectl rollout restart deployment -n oauth2-proxy
```

### Delete Stuck Pods
```bash
kubectl delete pod POD_NAME -n NAMESPACE --force --grace-period=0
```

### Reset Dex Auth
```bash
kubectl delete pods -n auth --all
kubectl delete pods -n oauth2-proxy --all
```

### Clear Failed Pods
```bash
kubectl delete pods --field-selector status.phase=Failed -n kubeflow
```

## 📚 Documentation

| File | Purpose |
|------|---------|
| README.md | Overview & quick start |
| DEPLOYMENT-GUIDE.md | Detailed deployment |
| CUSTOMIZATION.md | Configuration options |
| SUMMARY.md | Package overview |
| QUICK-REFERENCE.md | This file |

## 🔗 Useful Links

- **Docs**: https://www.kubeflow.org/docs/
- **Slack**: #kubeflow-platform on CNCF
- **GitHub**: https://github.com/kubeflow/manifests
- **Community**: https://www.kubeflow.org/docs/about/community/

## 💡 Pro Tips

1. **Always backup before upgrades**
   ```bash
   kubectl get pvc -n kubeflow -o yaml > backup.yaml
   ```

2. **Use ArgoCD for production**
   - Automatic sync
   - Easy rollback
   - Git as source of truth

3. **Monitor resource usage**
   ```bash
   watch kubectl top pods -n kubeflow
   ```

4. **Enable debug logging**
   ```bash
   kubectl set env deployment/dex LOG_LEVEL=debug -n auth
   ```

5. **Test in dev first**
   - Use staging environment
   - Test upgrades
   - Validate configurations

## ⚡ Quick Wins

### Speed up deployment
```bash
# Increase retry timeout
kubectl wait --for=condition=Ready pods --all -n kubeflow --timeout=600s
```

### Reduce resource usage
```yaml
# Disable unused components
katib.enabled: false
sparkOperator.enabled: false
```

### Improve security
```yaml
# Enable strict mTLS
istio.serviceMesh.mtls.mode: STRICT
```

### Better monitoring
```yaml
# Enable ServiceMonitors
serviceMonitor.enabled: true
```

---

**Need more help?** See README.md or DEPLOYMENT-GUIDE.md

**Found a bug?** Open an issue on GitHub

**Have questions?** Join us on Slack!

Happy ML Engineering! 🚀

