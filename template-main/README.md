# Kubernetes Application Template

A comprehensive Helm chart template for deploying applications on Kubernetes with Istio service mesh, cert-manager TLS certificates, and Longhorn storage. This template is based on battle-tested patterns from the `ollama-k8s` and `openwebui-k8s` projects.

## Features

✅ **Production-ready Helm chart template**  
✅ **Istio service mesh integration** with mTLS, gateways, and virtual services  
✅ **Cert-manager TLS certificates** with Let's Encrypt  
✅ **Longhorn persistent storage** with retain policy  
✅ **ArgoCD GitOps deployment** with sync waves  
✅ **Manual Istio sidecar fallback** for injection issues  
✅ **Comprehensive security contexts** and RBAC  
✅ **Horizontal Pod Autoscaling** support  
✅ **Network policies** for traffic control  
✅ **Service monitoring** with Prometheus  
✅ **Pod disruption budgets** for high availability  
✅ **GPU support** for NVIDIA workloads  
✅ **Flexible configuration** with extensive customization options

## Quick Start

### 1. Copy the Template

```bash
# Copy this template to your new project
cp -r template/ my-new-app/
cd my-new-app/
```

### 2. Customize Chart Metadata

Edit `Chart.yaml`:
```yaml
apiVersion: v2
name: "my-app"  # Change this
description: "My awesome Kubernetes application"  # Change this
version: "0.1.0"
appVersion: "1.0.0"  # Your app version
```

### 3. Configure Application Values

Edit `values.yaml`:
```yaml
app:
  name: "my-app"  # Your app name
  description: "My awesome application"
  version: "1.0.0"

image:
  repository: "my-registry/my-app"  # Your image
  tag: "1.0.0"

istio:
  gateway:
    hosts:
      - "myapp.example.com"  # Your domain

service:
  targetPort: 8080  # Your app port
```

### 4. Deploy with ArgoCD

1. Edit `argocd-application.yaml` with your repository and configuration
2. Apply to your cluster:
   ```bash
   kubectl apply -f argocd-application.yaml
   ```

## Architecture

This template creates the following resources with proper ArgoCD sync waves:

```
Wave 1: Namespace
Wave 2: ServiceAccount, Secret, ConfigMap
Wave 3: PVC (Persistent Volume Claim)
Wave 4: Certificate (cert-manager)
Wave 5: Gateway (Istio)
Wave 6: VirtualService, DestinationRule, PeerAuth, JWT Policy (Istio)
Wave 7: Service, NetworkPolicy
Wave 8: Deployment
Wave 9: HPA, PDB, ServiceMonitor
```

## Configuration Guide

### Core Application Settings

```yaml
app:
  name: "my-app"                    # Application name
  description: "My application"     # Description
  version: "1.0.0"                 # Application version
  homepage: "https://example.com"   # Homepage URL
  sourceUrl: "https://github.com/example/app"  # Source repository

image:
  repository: "nginx"               # Container image
  tag: "latest"                    # Image tag
  pullPolicy: IfNotPresent         # Pull policy

replicaCount: 1                     # Number of replicas
```

### Istio Service Mesh Configuration

```yaml
istio:
  enabled: true                     # Enable Istio integration
  sidecarInjection: true           # Auto sidecar injection
  manualSidecar:
    enabled: true                  # Manual sidecar fallback
    tag: "1.27.0"                 # Istio version
  
  gateway:
    enabled: true                  # Create Istio Gateway
    name: "my-app-gateway"        # Gateway name
    hosts:
      - "myapp.example.com"       # Your domains
  
  virtualService:
    enabled: true                  # Create VirtualService
    timeout: 30s                  # Request timeout
    retries:
      attempts: 3                 # Retry attempts
      perTryTimeout: 10s         # Per-try timeout
  
  destinationRule:
    enabled: true                  # Create DestinationRule
    tlsMode: "ISTIO_MUTUAL"       # mTLS mode
  
  serviceMesh:
    enabled: true                  # Enable service mesh features
    mtls:
      enabled: true               # Enable mTLS
      mode: STRICT                # mTLS mode
  
  jwt:
    enabled: false                # JWT authentication
    issuer: "my-app-service"      # JWT issuer
    audiences: ["other-service"]   # JWT audiences
  
  peerAuth:
    enabled: true                 # Peer authentication
    mode: STRICT                  # Auth mode
```

### Cert-manager TLS Configuration

```yaml
certManager:
  enabled: true                   # Enable cert-manager
  issuer: "letsencrypt-prod"     # ClusterIssuer name
  secretName: "my-app-tls-cert"  # TLS secret name
  duration: "8760h"              # Certificate duration (1 year)
  renewBefore: "720h"            # Renew before expiry (30 days)
```

### Storage Configuration

```yaml
persistence:
  enabled: true                   # Enable persistent storage
  storageClass: "longhorn-retain" # Storage class
  accessMode: ReadWriteOnce       # Access mode
  size: 10Gi                     # Storage size
  mountPath: "/data"             # Mount path in container
  reclaimPolicy: "Retain"        # Reclaim policy
  annotations:
    longhorn.io/allow-volume-creation-with-degraded-availability: "true"
```

### Resource Management

```yaml
resources:
  limits:
    cpu: 1000m                    # CPU limit
    memory: 2Gi                   # Memory limit
  requests:
    cpu: 500m                     # CPU request
    memory: 1Gi                   # Memory request

# GPU support (NVIDIA)
gpu:
  enabled: false                  # Enable GPU
  type: "nvidia"                  # GPU type
  count: 1                       # GPU count
  runtimeClassName: ""           # Runtime class

# Horizontal Pod Autoscaler
autoscaling:
  enabled: false                  # Enable HPA
  minReplicas: 1                 # Minimum replicas
  maxReplicas: 10                # Maximum replicas
  targetCPUUtilizationPercentage: 80    # CPU target
  targetMemoryUtilizationPercentage: 80 # Memory target
```

### Security Configuration

```yaml
serviceAccount:
  create: true                    # Create ServiceAccount
  annotations: {}                 # SA annotations
  name: ""                       # SA name (auto-generated if empty)

podSecurityContext:
  fsGroup: 2000                  # File system group

securityContext:
  capabilities:
    drop:
    - ALL                        # Drop all capabilities
  readOnlyRootFilesystem: false  # Read-only root filesystem
  runAsNonRoot: true             # Run as non-root
  runAsUser: 1000                # User ID

# Secrets management
existingSecret: ""               # Use existing secret
secrets: {}                      # Create new secrets
  # API_KEY: "secret-value"
  # DB_PASSWORD: "another-secret"
```

### Networking Configuration

```yaml
service:
  type: ClusterIP                 # Service type
  port: 80                       # Service port
  targetPort: 8080               # Container port
  additionalPorts: []            # Additional ports

# LoadBalancer (alternative to Istio Gateway)
loadBalancer:
  enabled: false                 # Enable LoadBalancer service
  type: LoadBalancer             # Service type
  port: 80                       # Port
  loadBalancerIP: ""            # Static IP

# Traditional Ingress (alternative to Istio Gateway)
ingress:
  enabled: false                 # Enable Ingress
  className: ""                  # Ingress class
  annotations: {}                # Ingress annotations
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: Prefix
  tls: []                       # TLS configuration

# Network policies
networkPolicy:
  enabled: false                 # Enable NetworkPolicy
  policyTypes:
    - Ingress
    - Egress
  ingress: []                   # Ingress rules
  egress: []                    # Egress rules
```

### Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /healthz              # Health check path
    port: http                  # Port
  initialDelaySeconds: 30       # Initial delay
  periodSeconds: 10             # Check interval
  timeoutSeconds: 5             # Timeout
  failureThreshold: 3           # Failure threshold

readinessProbe:
  httpGet:
    path: /healthz              # Readiness check path
    port: http                  # Port
  initialDelaySeconds: 5        # Initial delay
  periodSeconds: 5              # Check interval
  timeoutSeconds: 3             # Timeout
  failureThreshold: 3           # Failure threshold

# Startup probe (for slow-starting apps)
startupProbe:
  enabled: false                # Enable startup probe
  httpGet:
    path: /healthz              # Startup check path
    port: http                  # Port
  initialDelaySeconds: 30       # Initial delay
  periodSeconds: 10             # Check interval
  failureThreshold: 30          # Failure threshold
```

### Monitoring and Observability

```yaml
# Prometheus ServiceMonitor
serviceMonitor:
  enabled: false                # Enable ServiceMonitor
  interval: 30s                 # Scrape interval
  path: /metrics                # Metrics path
  labels: {}                    # Additional labels

# Pod disruption budget
podDisruptionBudget:
  enabled: false                # Enable PDB
  minAvailable: 1               # Minimum available pods
  # maxUnavailable: 1           # Maximum unavailable pods
```

### Advanced Configuration

```yaml
# Node placement
nodeSelector:
  kubernetes.io/hostname: "k8s-worker-1"  # Target node

tolerations: []                 # Pod tolerations
affinity: {}                   # Pod affinity rules

# Init containers
initContainers: []
  # - name: data-permission-fix
  #   image: busybox:1.35
  #   command: ["/bin/sh"]
  #   args:
  #     - -c
  #     - |
  #       chown -R 1000:2000 /data
  #       chmod -R 755 /data

# Additional containers (sidecars)
additionalContainers: []
  # - name: sidecar
  #   image: sidecar:latest
  #   ports:
  #     - containerPort: 9090

# Additional volumes
additionalVolumes: []
  # - name: config
  #   configMap:
  #     name: my-config

# Additional volume mounts
additionalVolumeMounts: []
  # - name: config
  #   mountPath: /etc/config

# ConfigMap
configMap:
  enabled: false                # Enable ConfigMap
  data: {}                      # ConfigMap data
    # config.yaml: |
    #   key: value

# Environment variables
env: []                         # Environment variables
  # - name: LOG_LEVEL
  #   value: "info"

envFrom: []                     # Environment from secrets/configmaps
  # - secretRef:
  #     name: my-secret
  # - configMapRef:
  #     name: my-configmap
```

## Deployment Examples

### Example 1: Simple Web Application

```yaml
app:
  name: "my-webapp"
  description: "My web application"
  version: "1.0.0"

image:
  repository: "nginx"
  tag: "1.21"

istio:
  gateway:
    hosts:
      - "webapp.example.com"

service:
  targetPort: 80

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Example 2: API Service with Database

```yaml
app:
  name: "my-api"
  description: "My API service"
  version: "2.0.0"

image:
  repository: "my-registry/api-service"
  tag: "2.0.0"

persistence:
  enabled: true
  size: 5Gi
  mountPath: "/app/data"

secrets:
  DATABASE_URL: "postgresql://user:pass@db:5432/mydb"
  API_KEY: "super-secret-api-key"

env:
  - name: LOG_LEVEL
    value: "info"
  - name: PORT
    value: "8080"

service:
  targetPort: 8080

livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 60

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 10
```

### Example 3: GPU-Enabled ML Application

```yaml
app:
  name: "ml-service"
  description: "Machine Learning Service"
  version: "1.0.0"

image:
  repository: "my-registry/ml-service"
  tag: "gpu-1.0.0"

gpu:
  enabled: true
  type: "nvidia"
  count: 1

resources:
  limits:
    cpu: 4000m
    memory: 8Gi
    nvidia.com/gpu: 1
  requests:
    cpu: 2000m
    memory: 4Gi

nodeSelector:
  accelerator: nvidia-tesla-v100

persistence:
  enabled: true
  size: 50Gi
  mountPath: "/app/models"

autoscaling:
  enabled: false  # Typically disabled for GPU workloads
```

## Troubleshooting

### Common Issues

#### 1. Istio Sidecar Not Injected

**Problem**: Pods don't have Istio sidecar containers.

**Solution**: The template includes manual sidecar injection as a fallback:
```yaml
istio:
  manualSidecar:
    enabled: true  # Enables manual sidecar injection
```

#### 2. Certificate Issues

**Problem**: TLS certificates not issued by cert-manager.

**Solutions**:
- Verify your ClusterIssuer exists: `kubectl get clusterissuer`
- Check certificate status: `kubectl get certificate -n istio-system`
- View cert-manager logs: `kubectl logs -n cert-manager deployment/cert-manager`

#### 3. Storage Issues

**Problem**: PVCs stuck in Pending state.

**Solutions**:
- Verify Longhorn storage class exists: `kubectl get storageclass`
- Check Longhorn system status: `kubectl get pods -n longhorn-system`
- Review PVC events: `kubectl describe pvc <pvc-name>`

#### 4. Pod Security Issues

**Problem**: Pods fail to start due to security constraints.

**Solutions**:
- Review security contexts in values.yaml
- Check pod security policies or admission controllers
- Verify service account permissions

### Debugging Commands

```bash
# Check pod status and events
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<app-name>
kubectl describe pod <pod-name> -n <namespace>

# View application logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=<app-name>

# Check Istio configuration
istioctl proxy-config cluster <pod-name>.<namespace>
istioctl proxy-status

# Verify certificates
kubectl get certificate -A
kubectl describe certificate <cert-name> -n <namespace>

# Check storage
kubectl get pvc -A
kubectl get pv

# Review Helm release
helm status <release-name> -n <namespace>
helm get values <release-name> -n <namespace>
```

## Contributing

This template is based on production deployments and real-world experience. Contributions and improvements are welcome!

### Template Structure

```
template/
├── Chart.yaml                    # Helm chart metadata
├── values.yaml                   # Default configuration values
├── argocd-application.yaml       # ArgoCD application template
├── README.md                     # This documentation
└── templates/                    # Kubernetes resource templates
    ├── _helpers.tpl              # Template helper functions
    ├── NOTES.txt                 # Post-installation notes
    ├── namespace.yaml            # Namespace creation
    ├── serviceaccount.yaml       # Service account
    ├── secret.yaml               # Secrets management
    ├── configmap.yaml            # Configuration maps
    ├── pvc.yaml                  # Persistent volume claims
    ├── deployment.yaml           # Main application deployment
    ├── service.yaml              # Kubernetes service
    ├── loadbalancer.yaml         # LoadBalancer service
    ├── ingress.yaml              # Traditional ingress
    ├── hpa.yaml                  # Horizontal Pod Autoscaler
    ├── poddisruptionbudget.yaml  # Pod disruption budget
    ├── networkpolicy.yaml        # Network policies
    ├── servicemonitor.yaml       # Prometheus monitoring
    ├── certificate.yaml          # Cert-manager certificates
    ├── istio-gateway.yaml        # Istio Gateway
    ├── istio-virtualservice.yaml # Istio VirtualService
    ├── istio-destinationrule.yaml # Istio DestinationRule
    ├── istio-peerauth.yaml       # Istio PeerAuthentication
    ├── istio-jwt-policy.yaml     # Istio JWT policies
    └── tests/
        └── test-connection.yaml  # Helm test
```

## License

This template is provided as-is for educational and production use. Based on the MIT License.

## Acknowledgments

This template is based on patterns and configurations from:
- **ollama-k8s**: Ollama deployment with Istio and Longhorn
- **openwebui-k8s**: Open WebUI deployment with comprehensive security
- Production Kubernetes deployments in enterprise environments

For questions or support, please refer to your DevOps team or create an issue in your project repository. 