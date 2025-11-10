#!/bin/bash
set -e

echo "========================================="
echo "Generating Helm templates from Kustomize"
echo "========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUSTOMIZE_DIR="$SCRIPT_DIR/../kubeflow-all-in-one"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
CRDS_DIR="$SCRIPT_DIR/crds"

# Clean existing templates (except helpers and wrapper)
echo "Cleaning old templates..."
find "$TEMPLATES_DIR" -name "*.yaml" ! -name "_helpers.tpl" ! -name "kustomize-wrapper.yaml" -delete 2>/dev/null || true

# Build kustomize output
echo "Building kustomize manifests..."
cd "$KUSTOMIZE_DIR"
kubectl kustomize . > /tmp/kubeflow-manifests.yaml

# Split into CRDs and regular resources
echo "Splitting CRDs and resources..."
python3 << 'PYTHON_SCRIPT'
import yaml
import os

with open('/tmp/kubeflow-manifests.yaml', 'r') as f:
    content = f.read()

docs = content.split('---\n')
crds = []
resources = {}

for doc in docs:
    if not doc.strip():
        continue
    
    try:
        obj = yaml.safe_load(doc)
        if not obj:
            continue
        
        kind = obj.get('kind', '')
        
        # Separate CRDs
        if kind == 'CustomResourceDefinition':
            crds.append(doc)
        else:
            # Group by kind
            if kind not in resources:
                resources[kind] = []
            resources[kind].append(doc)
    
    except Exception as e:
        print(f"Warning: Could not parse document: {e}")

# Write CRDs
crds_dir = os.environ.get('CRDS_DIR', 'crds')
os.makedirs(crds_dir, exist_ok=True)

print(f"Writing {len(crds)} CRDs...")
with open(f'{crds_dir}/kubeflow-crds.yaml', 'w') as f:
    f.write('---\n'.join(crds))

# Write resources by kind
templates_dir = os.environ.get('TEMPLATES_DIR', 'templates')
os.makedirs(templates_dir, exist_ok=True)

for kind, docs in resources.items():
    if not kind:
        continue
    
    filename = f'{templates_dir}/{kind.lower()}.yaml'
    print(f"Writing {len(docs)} {kind} resources to {filename}")
    
    with open(filename, 'w') as f:
        # Add Helm template header
        f.write('{{- if .Values.global }}\n')
        f.write(f'# {kind} resources\n')
        f.write('---\n'.join(docs))
        f.write('\n{{- end }}\n')

print(f"\n✅ Generated {len(resources)} resource types")
PYTHON_SCRIPT

echo ""
echo "========================================="
echo "✅ Helm templates generated successfully!"
echo "========================================="
echo ""
echo "CRDs: $CRDS_DIR/"
echo "Templates: $TEMPLATES_DIR/"
echo ""
echo "Next steps:"
echo "1. Review generated templates"
echo "2. Add Helm templating where needed ({{ .Values.* }})"
echo "3. Test: helm template kubeflow ."
echo "========================================="

