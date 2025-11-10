#!/bin/bash

# Kubernetes Application Template Setup Script
# This script helps you customize the template for your application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Kubernetes Application Template Setup                     ║"
    echo "║                                                                              ║"
    echo "║  This script will help you customize the template for your application      ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    echo -n "$prompt [$default]: "
    read -r input
    if [[ -z "$input" ]]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

# Function to prompt for yes/no with default
prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    while true; do
        echo -n "$prompt [y/n, default: $default]: "
        read -r input
        if [[ -z "$input" ]]; then
            input="$default"
        fi
        case $input in
            [Yy]* ) eval "$var_name=true"; break;;
            [Nn]* ) eval "$var_name=false"; break;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# Function to update values in files
update_file() {
    local file="$1"
    local search="$2"
    local replace="$3"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|$search|$replace|g" "$file"
    else
        # Linux
        sed -i "s|$search|$replace|g" "$file"
    fi
}

# Main setup function
main() {
    print_header
    
    # Check if we're in the right directory
    if [[ ! -f "Chart.yaml" ]] || [[ ! -f "values.yaml" ]]; then
        print_error "This script should be run from the template directory containing Chart.yaml and values.yaml"
        exit 1
    fi
    
    print_info "This script will customize the template for your application."
    print_info "Press Enter to accept default values in brackets.\n"
    
    # Collect application information
    echo -e "${YELLOW}Application Information:${NC}"
    prompt_with_default "Application name" "my-app" APP_NAME
    prompt_with_default "Application description" "My Kubernetes application" APP_DESCRIPTION
    prompt_with_default "Application version" "1.0.0" APP_VERSION
    prompt_with_default "Application homepage" "https://example.com" APP_HOMEPAGE
    prompt_with_default "Source repository URL" "https://github.com/example/my-app" SOURCE_URL
    prompt_with_default "Maintainer name" "DevOps Team" MAINTAINER_NAME
    prompt_with_default "Maintainer email" "devops@example.com" MAINTAINER_EMAIL
    
    echo ""
    echo -e "${YELLOW}Container Configuration:${NC}"
    prompt_with_default "Container image repository" "nginx" IMAGE_REPO
    prompt_with_default "Container image tag" "latest" IMAGE_TAG
    prompt_with_default "Container port" "8080" CONTAINER_PORT
    
    echo ""
    echo -e "${YELLOW}Kubernetes Configuration:${NC}"
    prompt_with_default "Kubernetes namespace" "$APP_NAME" NAMESPACE
    prompt_with_default "Target node hostname" "k8s-worker-1" NODE_HOSTNAME
    
    echo ""
    echo -e "${YELLOW}Istio Configuration:${NC}"
    prompt_yes_no "Enable Istio service mesh" "y" ISTIO_ENABLED
    
    if [[ "$ISTIO_ENABLED" == "true" ]]; then
        prompt_with_default "Domain name for Istio Gateway" "$APP_NAME.19980219.xyz" DOMAIN_NAME
        prompt_with_default "Gateway name" "$APP_NAME-gateway" GATEWAY_NAME
        prompt_yes_no "Enable cert-manager TLS certificates" "y" CERT_MANAGER_ENABLED
        
        if [[ "$CERT_MANAGER_ENABLED" == "true" ]]; then
            prompt_with_default "Cert-manager ClusterIssuer name" "letsencrypt-prod" CERT_ISSUER
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}Storage Configuration:${NC}"
    prompt_yes_no "Enable persistent storage" "n" STORAGE_ENABLED
    
    if [[ "$STORAGE_ENABLED" == "true" ]]; then
        prompt_with_default "Storage size" "10Gi" STORAGE_SIZE
        prompt_with_default "Storage mount path" "/data" STORAGE_PATH
        prompt_with_default "Storage class" "longhorn-retain" STORAGE_CLASS
    fi
    
    echo ""
    echo -e "${YELLOW}Resource Configuration:${NC}"
    prompt_with_default "CPU request" "500m" CPU_REQUEST
    prompt_with_default "CPU limit" "1000m" CPU_LIMIT
    prompt_with_default "Memory request" "1Gi" MEMORY_REQUEST
    prompt_with_default "Memory limit" "2Gi" MEMORY_LIMIT
    
    echo ""
    echo -e "${YELLOW}Scaling Configuration:${NC}"
    prompt_yes_no "Enable Horizontal Pod Autoscaler" "n" HPA_ENABLED
    
    if [[ "$HPA_ENABLED" == "true" ]]; then
        prompt_with_default "Minimum replicas" "2" MIN_REPLICAS
        prompt_with_default "Maximum replicas" "10" MAX_REPLICAS
        prompt_with_default "CPU target percentage" "70" CPU_TARGET
    fi
    
    echo ""
    print_info "Updating template files with your configuration..."
    
    # Update Chart.yaml
    update_file "Chart.yaml" "my-app" "$APP_NAME"
    update_file "Chart.yaml" "My Kubernetes application" "$APP_DESCRIPTION"
    update_file "Chart.yaml" "0.1.0" "$APP_VERSION"
    update_file "Chart.yaml" "latest" "$APP_VERSION"
    update_file "Chart.yaml" "https://example.com" "$APP_HOMEPAGE"
    update_file "Chart.yaml" "https://github.com/example/my-app" "$SOURCE_URL"
    update_file "Chart.yaml" "DevOps Team" "$MAINTAINER_NAME"
    update_file "Chart.yaml" "devops@example.com" "$MAINTAINER_EMAIL"
    
    # Update values.yaml
    update_file "values.yaml" "my-app" "$APP_NAME"
    update_file "values.yaml" "My Kubernetes application" "$APP_DESCRIPTION"
    update_file "values.yaml" "latest" "$APP_VERSION"
    update_file "values.yaml" "https://example.com" "$APP_HOMEPAGE"
    update_file "values.yaml" "https://github.com/example/my-app" "$SOURCE_URL"
    update_file "values.yaml" "DevOps Team" "$MAINTAINER_NAME"
    update_file "values.yaml" "devops@example.com" "$MAINTAINER_EMAIL"
    
    update_file "values.yaml" "nginx" "$IMAGE_REPO"
    update_file "values.yaml" "8080" "$CONTAINER_PORT"
    update_file "values.yaml" "k8s-worker-1" "$NODE_HOSTNAME"
    
    # Update resource limits
    update_file "values.yaml" "cpu: 500m" "cpu: $CPU_REQUEST"
    update_file "values.yaml" "cpu: 1000m" "cpu: $CPU_LIMIT"
    update_file "values.yaml" "memory: 1Gi" "memory: $MEMORY_REQUEST"
    update_file "values.yaml" "memory: 2Gi" "memory: $MEMORY_LIMIT"
    
    # Update Istio configuration
    if [[ "$ISTIO_ENABLED" == "false" ]]; then
        update_file "values.yaml" "enabled: true" "enabled: false"
    else
        update_file "values.yaml" "myapp.19980219.xyz" "$DOMAIN_NAME"
        update_file "values.yaml" "my-app-gateway" "$GATEWAY_NAME"
        
        if [[ "$CERT_MANAGER_ENABLED" == "false" ]]; then
            update_file "values.yaml" "certManager:" "certManager:"
            update_file "values.yaml" "  enabled: true" "  enabled: false"
        else
            update_file "values.yaml" "letsencrypt-prod" "$CERT_ISSUER"
        fi
    fi
    
    # Update storage configuration
    if [[ "$STORAGE_ENABLED" == "true" ]]; then
        update_file "values.yaml" "persistence:" "persistence:"
        update_file "values.yaml" "  enabled: false" "  enabled: true"
        update_file "values.yaml" "  size: 10Gi" "  size: $STORAGE_SIZE"
        update_file "values.yaml" '  mountPath: "/data"' "  mountPath: \"$STORAGE_PATH\""
        update_file "values.yaml" "longhorn-retain" "$STORAGE_CLASS"
    fi
    
    # Update HPA configuration
    if [[ "$HPA_ENABLED" == "true" ]]; then
        update_file "values.yaml" "autoscaling:" "autoscaling:"
        update_file "values.yaml" "  enabled: false" "  enabled: true"
        update_file "values.yaml" "  minReplicas: 1" "  minReplicas: $MIN_REPLICAS"
        update_file "values.yaml" "  maxReplicas: 100" "  maxReplicas: $MAX_REPLICAS"
        update_file "values.yaml" "  targetCPUUtilizationPercentage: 80" "  targetCPUUtilizationPercentage: $CPU_TARGET"
    fi
    
    # Update ArgoCD application template
    if [[ -f "argocd-application.yaml" ]]; then
        update_file "argocd-application.yaml" "name: my-app" "name: $APP_NAME"
        update_file "argocd-application.yaml" "namespace: my-app" "namespace: $NAMESPACE"
        update_file "argocd-application.yaml" '"my-app"' "\"$APP_NAME\""
        update_file "argocd-application.yaml" "My Kubernetes application" "$APP_DESCRIPTION"
        update_file "argocd-application.yaml" "nginx" "$IMAGE_REPO"
        update_file "argocd-application.yaml" "myapp.19980219.xyz" "$DOMAIN_NAME"
        update_file "argocd-application.yaml" "8080" "$CONTAINER_PORT"
    fi
    
    print_success "Template customization completed!"
    
    echo ""
    print_info "Next steps:"
    echo "1. Review and adjust the generated values.yaml file"
    echo "2. Update the argocd-application.yaml with your Git repository URL"
    echo "3. Commit your changes to Git"
    echo "4. Apply the ArgoCD application: kubectl apply -f argocd-application.yaml"
    
    echo ""
    print_info "Files updated:"
    echo "- Chart.yaml"
    echo "- values.yaml"
    echo "- argocd-application.yaml (if present)"
    
    echo ""
    print_warning "Remember to:"
    echo "- Replace placeholder secrets in values.yaml with actual values"
    echo "- Update health check paths to match your application"
    echo "- Adjust resource limits based on your application's needs"
    echo "- Configure environment-specific values files if needed"
    
    echo ""
    print_success "Setup complete! Your template is ready for deployment."
}

# Run the main function
main "$@" 