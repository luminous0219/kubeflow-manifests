# Template Usage Examples

This document provides practical examples of using the Kubernetes Application Template for different types of applications.

## Example 1: Simple Web Application (Nginx)

A basic web application serving static content.

### values.yaml
```yaml
app:
  name: "company-website"
  description: "Company marketing website"
  version: "1.0.0"
  homepage: "https://company.com"

image:
  repository: "nginx"
  tag: "1.21-alpine"

namespace:
  name: "company-website"

istio:
  gateway:
    hosts:
      - "company.com"
      - "www.company.com"

service:
  port: 80
  targetPort: 80

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi

persistence:
  enabled: true
  size: 1Gi
  mountPath: "/usr/share/nginx/html"

livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
```

## Example 2: Node.js API Service

A REST API service with database connectivity and secrets management.

### values.yaml
```yaml
app:
  name: "user-api"
  description: "User management API service"
  version: "2.1.0"
  homepage: "https://api.company.com"
  sourceUrl: "https://github.com/company/user-api"

image:
  repository: "company/user-api"
  tag: "2.1.0"

namespace:
  name: "user-api"

istio:
  gateway:
    hosts:
      - "api.company.com"
  jwt:
    enabled: true
    issuer: "user-api-service"
    audiences: ["frontend-app", "mobile-app"]

service:
  port: 80
  targetPort: 3000

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

secrets:
  DATABASE_URL: "postgresql://api_user:secure_password@postgres:5432/userdb"
  JWT_SECRET: "your-super-secret-jwt-key"
  REDIS_URL: "redis://redis:6379/1"

env:
  - name: NODE_ENV
    value: "production"
  - name: PORT
    value: "3000"
  - name: LOG_LEVEL
    value: "info"
  - name: API_VERSION
    value: "v1"

livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 60
  periodSeconds: 30
  timeoutSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 5

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

## Example 3: Python ML Service with GPU

A machine learning inference service requiring GPU resources.

### values.yaml
```yaml
app:
  name: "ml-inference"
  description: "Machine Learning Inference Service"
  version: "1.0.0"
  homepage: "https://ml.company.com"

image:
  repository: "company/ml-inference"
  tag: "1.0.0-gpu"

namespace:
  name: "ml-inference"

istio:
  gateway:
    hosts:
      - "ml.company.com"
  virtualService:
    timeout: 300s  # Longer timeout for ML inference
    retries:
      attempts: 2
      perTryTimeout: 300s

service:
  port: 80
  targetPort: 8000

gpu:
  enabled: true
  type: "nvidia"
  count: 1

resources:
  requests:
    cpu: 2000m
    memory: 4Gi
  limits:
    cpu: 8000m
    memory: 16Gi
    nvidia.com/gpu: 1

nodeSelector:
  accelerator: nvidia-tesla-v100
  node-type: gpu-node

persistence:
  enabled: true
  size: 50Gi
  mountPath: "/app/models"
  storageClass: "fast-ssd"

env:
  - name: CUDA_VISIBLE_DEVICES
    value: "0"
  - name: MODEL_PATH
    value: "/app/models"
  - name: BATCH_SIZE
    value: "32"
  - name: WORKERS
    value: "4"

livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 120  # Longer startup time for model loading
  periodSeconds: 60
  timeoutSeconds: 30

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 60
  periodSeconds: 30
  timeoutSeconds: 15

# Typically don't enable autoscaling for GPU workloads
autoscaling:
  enabled: false

# Ensure only one pod goes down at a time
podDisruptionBudget:
  enabled: true
  maxUnavailable: 1
```

## Example 4: Database Application with StatefulSet-like Configuration

A database or stateful application requiring persistent storage and specific startup ordering.

### values.yaml
```yaml
app:
  name: "redis-cache"
  description: "Redis Cache Service"
  version: "6.2.0"

image:
  repository: "redis"
  tag: "6.2-alpine"

namespace:
  name: "redis-cache"

# Disable Istio for database workloads if not needed
istio:
  enabled: false

service:
  port: 6379
  targetPort: 6379
  type: ClusterIP

resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 2Gi

persistence:
  enabled: true
  size: 20Gi
  mountPath: "/data"
  storageClass: "longhorn-retain"
  accessMode: ReadWriteOnce

# Redis-specific configuration
configMap:
  enabled: true
  data:
    redis.conf: |
      bind 0.0.0.0
      port 6379
      dir /data
      save 900 1
      save 300 10
      save 60 10000
      rdbcompression yes
      rdbchecksum yes
      maxmemory 1gb
      maxmemory-policy allkeys-lru

env:
  - name: REDIS_CONF
    value: "/etc/redis/redis.conf"

# Custom startup command
additionalVolumeMounts:
  - name: config
    mountPath: /etc/redis
    readOnly: true

# Redis doesn't have standard HTTP health checks
livenessProbe:
  exec:
    command:
      - redis-cli
      - ping
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  exec:
    command:
      - redis-cli
      - ping
  initialDelaySeconds: 5
  periodSeconds: 5

# Single replica for Redis (or use Redis Cluster for HA)
replicaCount: 1
autoscaling:
  enabled: false

# Ensure data persistence
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Network policy for database security
networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: user-api
      - namespaceSelector:
          matchLabels:
            name: frontend-app
      ports:
      - protocol: TCP
        port: 6379
```

## Example 5: Frontend Application (React/Vue/Angular)

A modern frontend application with build-time configuration.

### values.yaml
```yaml
app:
  name: "company-frontend"
  description: "Company Frontend Application"
  version: "1.5.0"
  homepage: "https://app.company.com"

image:
  repository: "company/frontend-app"
  tag: "1.5.0"

namespace:
  name: "company-frontend"

istio:
  gateway:
    hosts:
      - "app.company.com"
  virtualService:
    headers:
      response:
        set:
          Cache-Control: "public, max-age=31536000"
          X-Frame-Options: "DENY"
          X-Content-Type-Options: "nosniff"
          Referrer-Policy: "strict-origin-when-cross-origin"

service:
  port: 80
  targetPort: 80

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Frontend apps typically don't need persistence
persistence:
  enabled: false

# Configuration via environment variables (build-time)
env:
  - name: REACT_APP_API_URL
    value: "https://api.company.com"
  - name: REACT_APP_VERSION
    value: "1.5.0"
  - name: REACT_APP_ENVIRONMENT
    value: "production"

# Simple HTTP health checks
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10

# Scale based on traffic
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 20
  targetCPUUtilizationPercentage: 60

podDisruptionBudget:
  enabled: true
  minAvailable: 1

# CDN-like behavior with multiple replicas
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - company-frontend
        topologyKey: kubernetes.io/hostname
```

## Example 6: Microservice with Service Mesh Integration

A microservice that communicates with other services in the mesh.

### values.yaml
```yaml
app:
  name: "order-service"
  description: "Order Management Microservice"
  version: "1.2.0"

image:
  repository: "company/order-service"
  tag: "1.2.0"

namespace:
  name: "order-service"

istio:
  enabled: true
  sidecarInjection: true
  manualSidecar:
    enabled: true
  
  # Internal service, no external gateway needed
  gateway:
    enabled: false
  
  # Service-to-service communication
  destinationRule:
    enabled: true
    tlsMode: "ISTIO_MUTUAL"
  
  # Strict mTLS for security
  serviceMesh:
    enabled: true
    mtls:
      enabled: true
      mode: STRICT
  
  # JWT for service authentication
  jwt:
    enabled: true
    issuer: "order-service"
    audiences: ["payment-service", "inventory-service"]

service:
  port: 80
  targetPort: 8080
  # Additional ports for gRPC
  additionalPorts:
    - name: grpc
      port: 9090
      targetPort: 9090

resources:
  requests:
    cpu: 300m
    memory: 512Mi
  limits:
    cpu: 1500m
    memory: 2Gi

secrets:
  DATABASE_URL: "postgresql://order_user:password@postgres:5432/orders"
  REDIS_URL: "redis://redis:6379/2"
  JWT_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"

env:
  - name: SERVICE_NAME
    value: "order-service"
  - name: SERVICE_VERSION
    value: "1.2.0"
  - name: GRPC_PORT
    value: "9090"
  - name: HTTP_PORT
    value: "8080"
  - name: PAYMENT_SERVICE_URL
    value: "http://payment-service.payment-service.svc.cluster.local"
  - name: INVENTORY_SERVICE_URL
    value: "http://inventory-service.inventory-service.svc.cluster.local"

# Health checks for both HTTP and gRPC
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 45
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 15
  periodSeconds: 10

# Startup probe for slower service initialization
startupProbe:
  enabled: true
  httpGet:
    path: /startup
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 30

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 15
  targetCPUUtilizationPercentage: 65
  targetMemoryUtilizationPercentage: 75

podDisruptionBudget:
  enabled: true
  minAvailable: 2

# Service mesh monitoring
serviceMonitor:
  enabled: true
  interval: 15s
  path: /metrics

# Restrict network access
networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: frontend-service
      - namespaceSelector:
          matchLabels:
            name: api-gateway
      ports:
      - protocol: TCP
        port: 8080
      - protocol: TCP
        port: 9090
  egress:
    - to:
      - namespaceSelector:
          matchLabels:
            name: payment-service
      ports:
      - protocol: TCP
        port: 80
    - to:
      - namespaceSelector:
          matchLabels:
            name: inventory-service
      ports:
      - protocol: TCP
        port: 80
```

## Example 7: Batch Job Application

An application that runs periodic batch jobs or data processing tasks.

### values.yaml
```yaml
app:
  name: "data-processor"
  description: "Data Processing Batch Job"
  version: "1.0.0"

image:
  repository: "company/data-processor"
  tag: "1.0.0"

namespace:
  name: "data-processor"

# Batch jobs typically don't need Istio
istio:
  enabled: false

service:
  port: 80
  targetPort: 8080

resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 4000m
    memory: 8Gi

# Large storage for data processing
persistence:
  enabled: true
  size: 100Gi
  mountPath: "/data"
  storageClass: "fast-ssd"

secrets:
  DATABASE_URL: "postgresql://processor:password@postgres:5432/analytics"
  S3_ACCESS_KEY: "your-s3-access-key"
  S3_SECRET_KEY: "your-s3-secret-key"

env:
  - name: BATCH_SIZE
    value: "1000"
  - name: PARALLEL_JOBS
    value: "4"
  - name: S3_BUCKET
    value: "company-data-lake"
  - name: OUTPUT_FORMAT
    value: "parquet"

# Longer timeouts for batch processing
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 120
  periodSeconds: 300  # Check every 5 minutes
  timeoutSeconds: 30
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 60
  periodSeconds: 60
  timeoutSeconds: 15

# Single replica for batch jobs to avoid conflicts
replicaCount: 1
autoscaling:
  enabled: false

# Ensure job completion
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Schedule on compute-optimized nodes
nodeSelector:
  node-type: compute-optimized
  
tolerations:
  - key: "batch-workload"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
```

## Common Patterns and Best Practices

### Environment-Specific Values

Create separate values files for different environments:

```bash
# values-dev.yaml - Development overrides
replicaCount: 1
autoscaling:
  enabled: false
resources:
  requests:
    cpu: 100m
    memory: 128Mi
istio:
  gateway:
    hosts:
      - "myapp-dev.company.com"

# values-staging.yaml - Staging overrides  
replicaCount: 2
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
istio:
  gateway:
    hosts:
      - "myapp-staging.company.com"

# values-prod.yaml - Production overrides
replicaCount: 3
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
podDisruptionBudget:
  enabled: true
networkPolicy:
  enabled: true
```

### ArgoCD Application Sets

For managing multiple applications with similar patterns:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - service: user-service
        namespace: user-service
        domain: users.company.com
      - service: order-service  
        namespace: order-service
        domain: orders.company.com
      - service: payment-service
        namespace: payment-service
        domain: payments.company.com
  template:
    metadata:
      name: '{{service}}'
    spec:
      project: default
      source:
        repoURL: https://gitlab.com/company/k8s-templates.git
        targetRevision: HEAD
        path: .
        helm:
          valueFiles:
            - values.yaml
          values: |
            app:
              name: "{{service}}"
            namespace:
              name: "{{namespace}}"
            istio:
              gateway:
                hosts:
                  - "{{domain}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

These examples demonstrate the flexibility and power of the Kubernetes Application Template. Each example can be customized further based on your specific requirements and infrastructure setup. 