# Kubeflow Large CRDs Helm Chart

This Helm chart deploys large Kubeflow CRDs that exceed ArgoCD's annotation size limits.

## Why Helm?

Helm handles large CRDs better than kubectl/ArgoCD because:
1. Helm stores release data in Secrets (not annotations)
2. Helm's three-way merge doesn't add large `last-applied-configuration` annotations
3. ArgoCD can deploy Helm charts without annotation issues

## Installation via ArgoCD

Create an ArgoCD Application that references this Helm chart:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeflow-crds
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/luminous0219/kubeflow-manifests.git
    targetRevision: HEAD
    path: kubeflow-crds-helm
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
```

## Manual Installation

```bash
helm install kubeflow-crds /home/ml/kubeflow-manifests/kubeflow-crds-helm
```

## What's Included

- `clustertrainingruntimes.trainer.kubeflow.org`
- `trainingruntimes.trainer.kubeflow.org`
- `trainjobs.trainer.kubeflow.org`

## Deployment Order

1. Deploy this chart first (CRDs)
2. Then deploy kubeflow-all-in-one (applications)

