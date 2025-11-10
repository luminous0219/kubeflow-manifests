# Kubeflow Customization Guide

This guide shows you how to customize your Kubeflow deployment for your specific needs.

## 📝 Table of Contents

- [Domain Configuration](#domain-configuration)
- [Authentication](#authentication)
- [Storage Configuration](#storage-configuration)
- [Component Selection](#component-selection)
- [Resource Limits](#resource-limits)
- [Pipeline Configuration](#pipeline-configuration)
- [Advanced Customization](#advanced-customization)

## 🌐 Domain Configuration

### Change Domain Name

Create a patch file to update the domain:

```yaml
# domain-patch.yaml
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
      value: ml.mycompany.com
    - op: replace
      path: /spec/servers/1/hosts/0
      value: ml.mycompany.com

- target:
    kind: ConfigMap
    name: dex
    namespace: auth
  patch: |-
    - op: replace
      path: /data/config.yaml
      value: |
        issuer: https://ml.mycompany.com/dex
        storage:
          type: kubernetes
          config:
            inCluster: true
        web:
          http: 0.0.0.0:5556
        logger:
          level: "debug"
          format: text
        oauth2:
          skipApprovalScreen: true
        enablePasswordDB: true
        staticPasswords:
        - email: user@example.com
          hashFromEnv: DEX_USER_PASSWORD
          username: user
          userID: "15841185641784"
        staticClients:
        - idEnv: OIDC_CLIENT_ID
          redirectURIs: ["/oauth2/callback"]
          name: 'Dex Login Application'
          secretEnv: OIDC_CLIENT_SECRET
```

Apply with:

```bash
kustomize build domain-patch.yaml | kubectl apply -f -
```

## 🔐 Authentication

### Change Default User

1. **Update user email and username:**

```yaml
# user-patch.yaml
patches:
- target:
    kind: ConfigMap
    name: dex
    namespace: auth
  patch: |-
    - op: replace
      path: /data/config.yaml
      value: |
        # ... (full config with updated email/username)
        staticPasswords:
        - email: admin@mycompany.com
          hashFromEnv: DEX_USER_PASSWORD
          username: admin
          userID: "15841185641784"

- target:
    kind: Profile
    name: kubeflow-user-example-com
  patch: |-
    - op: replace
      path: /metadata/name
      value: kubeflow-user-admin-mycompany-com
    - op: replace
      path: /spec/owner/name
      value: admin@mycompany.com
```

2. **Generate and set password:**

```bash
# Generate password hash
python3 -c 'from passlib.hash import bcrypt; import getpass; print(bcrypt.using(rounds=12, ident="2y").hash(getpass.getpass()))'

# Update secret
kubectl create secret generic dex-passwords \
  --from-literal=DEX_USER_PASSWORD='YOUR_HASH' \
  -n auth --dry-run=client -o yaml | kubectl apply -f -

# Restart Dex
kubectl rollout restart deployment/dex -n auth
```

### Add Azure AD Authentication

```yaml
# azure-ad-connector.yaml
patches:
- target:
    kind: ConfigMap
    name: dex
    namespace: auth
  patch: |-
    - op: add
      path: /data/config.yaml
      value: |
        issuer: https://kubeflow.mycompany.com/dex
        storage:
          type: kubernetes
          config:
            inCluster: true
        web:
          http: 0.0.0.0:5556
        logger:
          level: "debug"
          format: text
        oauth2:
          skipApprovalScreen: true
        enablePasswordDB: true
        staticPasswords:
        - email: user@example.com
          hashFromEnv: DEX_USER_PASSWORD
          username: user
          userID: "15841185641784"
        staticClients:
        - idEnv: OIDC_CLIENT_ID
          redirectURIs: ["/oauth2/callback"]
          name: 'Dex Login Application'
          secretEnv: OIDC_CLIENT_SECRET
        connectors:
        - type: oidc
          id: azure
          name: Azure AD
          config:
            issuer: https://login.microsoftonline.com/YOUR_TENANT_ID/v2.0
            clientID: YOUR_CLIENT_ID
            clientSecret: YOUR_CLIENT_SECRET
            redirectURI: https://kubeflow.mycompany.com/dex/callback
            scopes:
              - openid
              - profile
              - email
            insecureSkipEmailVerified: true

- target:
    kind: Deployment
    name: dex
    namespace: auth
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: AZURE_CLIENT_ID
        value: "YOUR_CLIENT_ID"
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: AZURE_CLIENT_SECRET
        value: "YOUR_CLIENT_SECRET"
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: TENANT_ID
        value: "YOUR_TENANT_ID"
```

### Add Google OAuth

```yaml
connectors:
- type: oidc
  id: google
  name: Google
  config:
    issuer: https://accounts.google.com
    clientID: YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com
    clientSecret: YOUR_GOOGLE_CLIENT_SECRET
    redirectURI: https://kubeflow.mycompany.com/dex/callback
    scopes:
      - openid
      - profile
      - email
```

### Add GitHub OAuth

```yaml
connectors:
- type: github
  id: github
  name: GitHub
  config:
    clientID: YOUR_GITHUB_CLIENT_ID
    clientSecret: YOUR_GITHUB_CLIENT_SECRET
    redirectURI: https://kubeflow.mycompany.com/dex/callback
    orgs:
    - name: your-github-org
```

## 💾 Storage Configuration

### Use Different Storage Class

```yaml
# storage-class-patch.yaml
patches:
- target:
    kind: PersistentVolumeClaim
  patch: |-
    - op: replace
      path: /spec/storageClassName
      value: my-storage-class
```

### Adjust Storage Sizes

```yaml
# storage-size-patch.yaml
patches:
# Increase Katib database size
- target:
    kind: PersistentVolumeClaim
    name: katib-mysql
    namespace: kubeflow
  patch: |-
    - op: replace
      path: /spec/resources/requests/storage
      value: 20Gi

# Increase Pipeline database size
- target:
    kind: PersistentVolumeClaim
    name: mysql-pv-claim
    namespace: kubeflow
  patch: |-
    - op: replace
      path: /spec/resources/requests/storage
      value: 50Gi

# Increase artifact storage
- target:
    kind: PersistentVolumeClaim
    name: minio-pvc
    namespace: kubeflow
  patch: |-
    - op: replace
      path: /spec/resources/requests/storage
      value: 100Gi
```

## 🧩 Component Selection

### Minimal Installation

Create a minimal kustomization with only essential components:

```yaml
# minimal-kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
# Authentication
- ../common/oauth2-proxy/overlays/m2m-dex-only
- ../common/dex/overlays/oauth2-proxy

# Core infrastructure
- ../common/kubeflow-namespace/base
- ../common/kubeflow-roles/base
- ../common/istio/kubeflow-istio-resources/base

# Essential components
- ../applications/centraldashboard/overlays/oauth2-proxy
- ../applications/profiles/pss
- ../applications/jupyter/jupyter-web-app/upstream/overlays/istio
- ../applications/jupyter/notebook-controller/upstream/overlays/kubeflow
- ../applications/volumes-web-app/upstream/overlays/istio

# User namespace
- ../common/user-namespace/base

components:
- ../common/security/PSS/dynamic/baseline
```

### ML Training Focus

For clusters focused on training:

```yaml
resources:
# Base components
- ../common/oauth2-proxy/overlays/m2m-dex-only
- ../common/dex/overlays/oauth2-proxy
- ../common/kubeflow-namespace/base
- ../common/kubeflow-roles/base
- ../common/istio/kubeflow-istio-resources/base

# Training components
- ../applications/centraldashboard/overlays/oauth2-proxy
- ../applications/profiles/pss
- ../applications/jupyter/jupyter-web-app/upstream/overlays/istio
- ../applications/jupyter/notebook-controller/upstream/overlays/kubeflow
- ../applications/katib/upstream/installs/katib-with-kubeflow
- ../applications/trainer/overlays
- ../applications/tensorboard/tensorboard-controller/upstream/overlays/kubeflow
- ../applications/tensorboard/tensorboards-web-app/upstream/overlays/istio

# User namespace
- ../common/user-namespace/base
```

### ML Serving Focus

For clusters focused on serving:

```yaml
resources:
# Base components
- ../common/oauth2-proxy/overlays/m2m-dex-only
- ../common/dex/overlays/oauth2-proxy
- ../common/knative/knative-serving/overlays/gateways
- ../common/istio/cluster-local-gateway/base
- ../common/kubeflow-namespace/base
- ../common/kubeflow-roles/base
- ../common/istio/kubeflow-istio-resources/base

# Serving components
- ../applications/centraldashboard/overlays/oauth2-proxy
- ../applications/profiles/pss
- ../applications/kserve/kserve
- ../applications/kserve/models-web-app/overlays/kubeflow

# User namespace
- ../common/user-namespace/base
```

## 📊 Resource Limits

### Adjust Resource Requests and Limits

```yaml
# resources-patch.yaml
patches:
# Central Dashboard
- target:
    kind: Deployment
    name: centraldashboard
    namespace: kubeflow
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: 1000m
          memory: 1Gi

# Pipeline API Server
- target:
    kind: Deployment
    name: ml-pipeline
    namespace: kubeflow
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 500m
          memory: 1Gi
        limits:
          cpu: 2000m
          memory: 4Gi

# Katib Controller
- target:
    kind: Deployment
    name: katib-controller
    namespace: kubeflow
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: 1000m
          memory: 2Gi
```

### Enable Autoscaling

```yaml
# hpa-patch.yaml
resources:
- hpa.yaml

---
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: centraldashboard-hpa
  namespace: kubeflow
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: centraldashboard
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## 🔄 Pipeline Configuration

### Use MinIO Instead of SeaweedFS

```yaml
# minio-pipeline.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
# Remove SeaweedFS
# - ../experimental/seaweedfs/istio

# Use MinIO-based pipeline
- ../applications/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user
```

### Use Kubernetes Native Pipeline Storage

```yaml
resources:
# Use K8s native pipeline definitions
- ../applications/pipeline/upstream/env/cert-manager/platform-agnostic-multi-user-k8s-native
```

### Configure External Database

```yaml
# external-db-patch.yaml
patches:
- target:
    kind: Deployment
    name: ml-pipeline
    namespace: kubeflow
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/env
      value:
      - name: DBCONFIG_USER
        value: "kubeflow"
      - name: DBCONFIG_PASSWORD
        valueFrom:
          secretKeyRef:
            name: mysql-secret
            key: password
      - name: DBCONFIG_HOST
        value: "mysql.database.svc.cluster.local"
      - name: DBCONFIG_PORT
        value: "3306"
      - name: DBCONFIG_DBNAME
        value: "mlpipeline"
```

## 🚀 Advanced Customization

### Node Affinity for GPU Workloads

```yaml
# gpu-affinity-patch.yaml
patches:
- target:
    kind: Deployment
    labelSelector: "app=notebook-controller"
  patch: |-
    - op: add
      path: /spec/template/spec/affinity
      value:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: accelerator
                operator: In
                values:
                - nvidia-tesla-v100
                - nvidia-tesla-a100
```

### Custom Notebook Images

```yaml
# custom-notebooks-patch.yaml
patches:
- target:
    kind: ConfigMap
    name: jupyter-web-app-config
    namespace: kubeflow
  patch: |-
    - op: add
      path: /data/spawner_ui_config.yaml
      value: |
        spawnerFormDefaults:
          image:
            value: my-registry.com/custom-notebook:latest
            options:
            - my-registry.com/custom-notebook:latest
            - my-registry.com/tensorflow-notebook:2.12.0
            - my-registry.com/pytorch-notebook:2.0.0
```

### Enable Istio mTLS STRICT Mode

```yaml
# strict-mtls-patch.yaml
patches:
- target:
    kind: PeerAuthentication
  patch: |-
    - op: replace
      path: /spec/mtls/mode
      value: STRICT
```

### Add Custom Network Policies

```yaml
# custom-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: kubeflow
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

### Configure Pod Disruption Budgets

```yaml
# pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ml-pipeline-pdb
  namespace: kubeflow
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: ml-pipeline
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: centraldashboard-pdb
  namespace: kubeflow
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: centraldashboard
```

## 🔧 Complete Custom Example

Here's a complete example combining multiple customizations:

```yaml
# my-kubeflow-kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
# Base Kubeflow installation
- ../kubeflow-all-in-one

# Additional resources
- custom-network-policy.yaml
- pdb.yaml
- hpa.yaml

patches:
# Domain configuration
- target:
    kind: Gateway
    name: kubeflow-gateway
  patch: |-
    - op: replace
      path: /spec/servers/0/hosts/0
      value: ml.mycompany.com
    - op: replace
      path: /spec/servers/1/hosts/0
      value: ml.mycompany.com

# Resource limits
- target:
    kind: Deployment
    name: ml-pipeline
    namespace: kubeflow
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/resources
      value:
        requests:
          cpu: 500m
          memory: 1Gi
        limits:
          cpu: 2000m
          memory: 4Gi

# Storage class
- target:
    kind: PersistentVolumeClaim
  patch: |-
    - op: replace
      path: /spec/storageClassName
      value: longhorn-retain

# Custom labels
commonLabels:
  environment: production
  team: ml-platform
  managed-by: argocd

# Custom annotations
commonAnnotations:
  company.com/owner: ml-team
  company.com/cost-center: engineering
```

Apply with:

```bash
kustomize build my-kubeflow-kustomization.yaml | kubectl apply -f -
```

## 📚 Additional Resources

- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Kubeflow Customization Guide](https://www.kubeflow.org/docs/started/installing-kubeflow/)
- [Dex Connectors](https://dexidp.io/docs/connectors/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)

## 💡 Tips

1. **Test patches locally** before applying to production
2. **Use separate overlays** for different environments (dev, staging, prod)
3. **Version control** all customizations
4. **Document** your customizations for team members
5. **Monitor resource usage** and adjust limits accordingly
6. **Regular backups** of configurations and data
7. **Test upgrades** in a non-production environment first

