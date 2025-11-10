#!/bin/bash
set -e

echo "========================================="
echo "Installing Kubeflow Large CRDs"
echo "========================================="
echo ""

echo "These CRDs are too large for ArgoCD to manage due to annotation size limits."
echo "Installing with server-side apply..."
echo ""

# Apply all CRDs with server-side apply
kubectl apply --server-side=true --force-conflicts -f large-crds/

echo ""
echo "✅ CRDs installed successfully!"
echo ""
echo "Verifying installation..."
kubectl get crd | grep -E "(trainer|kserve|jobset|spark)" || true

echo ""
echo "========================================="
echo "Next Steps:"
echo "1. Deploy kubeflow-part-2-apps via ArgoCD"
echo "2. Monitor the deployment"
echo "========================================="

