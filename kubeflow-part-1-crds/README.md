# Kubeflow Part 1: CRDs Installation

This part installs only the Custom Resource Definitions (CRDs) that are too large to be managed by ArgoCD due to annotation size limits.

## Why Split?

Some Kubeflow CRDs (especially Trainer, KServe, JobSet, and Spark Operator) are very large (>800KB). When ArgoCD applies them, Kubernetes adds a `last-applied-configuration` annotation containing the entire CRD spec, which exceeds the 262KB annotation limit.

## Installation

These CRDs must be installed using `kubectl apply --server-side` which doesn't add the large annotation:

```bash
# Install large CRDs directly
kubectl apply --server-side=true --force-conflicts -f /home/ml/kubeflow-manifests/kubeflow-part-1-crds/large-crds/
```

Or use the provided script:

```bash
cd /home/ml/kubeflow-manifests/kubeflow-part-1-crds
./install-crds.sh
```

## What's Included

- Trainer CRDs (ClusterTrainingRuntime, TrainingRuntime, TrainJob)
- KServe CRDs (InferenceService, etc.)
- JobSet CRDs
- Spark Operator CRDs

## After Installation

Once these CRDs are installed, proceed with Part 2 (kubeflow-part-2-apps) via ArgoCD.

