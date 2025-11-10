#!/bin/bash

# Kubeflow All-in-One Installation Script
# This script deploys Kubeflow assuming cert-manager, Istio, and Longhorn are already installed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    
    print_info "Waiting for pods in namespace '$namespace' to be ready (timeout: ${timeout}s)..."
    
    if kubectl wait --for=condition=Ready pods --all -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        print_success "All pods in namespace '$namespace' are ready"
        return 0
    else
        print_warning "Some pods in namespace '$namespace' are not ready yet"
        kubectl get pods -n "$namespace" | grep -v "Running\|Completed" || true
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    print_success "kubectl is installed"
    
    # Check kustomize
    if ! command_exists kustomize; then
        print_error "kustomize is not installed. Please install kustomize v5.4.3+ first."
        exit 1
    fi
    
    local kustomize_version=$(kustomize version --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' || echo "unknown")
    print_success "kustomize is installed (version: $kustomize_version)"
    
    # Check cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"
    
    # Check Istio
    if ! kubectl get namespace istio-system >/dev/null 2>&1; then
        print_error "Istio namespace not found. Please install Istio first."
        exit 1
    fi
    print_success "Istio is installed"
    
    # Check cert-manager
    if ! kubectl get namespace cert-manager >/dev/null 2>&1; then
        print_error "cert-manager namespace not found. Please install cert-manager first."
        exit 1
    fi
    print_success "cert-manager is installed"
    
    # Check for ClusterIssuer
    if ! kubectl get clusterissuer >/dev/null 2>&1; then
        print_warning "No ClusterIssuer found. You may need to create one for TLS certificates."
    else
        print_success "ClusterIssuer(s) found"
    fi
    
    # Check Longhorn or other storage class
    if ! kubectl get storageclass >/dev/null 2>&1; then
        print_error "No StorageClass found. Please install Longhorn or configure another storage provider."
        exit 1
    fi
    print_success "StorageClass(es) found"
    
    print_success "All prerequisites are met!"
}

# Function to apply manifests with retry
apply_with_retry() {
    local max_attempts=5
    local attempt=1
    local wait_time=20
    
    print_info "Applying Kubeflow manifests (this may take several minutes)..."
    
    while [ $attempt -le $max_attempts ]; do
        print_info "Attempt $attempt of $max_attempts..."
        
        if kustomize build . | kubectl apply --server-side --force-conflicts -f -; then
            print_success "Manifests applied successfully!"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                print_warning "Application failed. Retrying in ${wait_time}s..."
                sleep $wait_time
                attempt=$((attempt + 1))
            else
                print_error "Failed to apply manifests after $max_attempts attempts"
                return 1
            fi
        fi
    done
}

# Function to display status
show_status() {
    print_info "Checking deployment status..."
    echo ""
    
    print_info "Namespaces:"
    kubectl get namespaces | grep -E "kubeflow|auth|oauth2-proxy|knative-serving" || true
    echo ""
    
    print_info "Pods in kubeflow namespace:"
    kubectl get pods -n kubeflow
    echo ""
    
    print_info "Pods in auth namespace:"
    kubectl get pods -n auth 2>/dev/null || print_warning "Auth namespace not found"
    echo ""
    
    print_info "Pods in oauth2-proxy namespace:"
    kubectl get pods -n oauth2-proxy 2>/dev/null || print_warning "OAuth2-proxy namespace not found"
    echo ""
    
    print_info "Pods in knative-serving namespace:"
    kubectl get pods -n knative-serving 2>/dev/null || print_warning "Knative-serving namespace not found"
    echo ""
}

# Function to get access information
show_access_info() {
    print_success "Kubeflow deployment completed!"
    echo ""
    print_info "========================================"
    print_info "  Kubeflow Access Information"
    print_info "========================================"
    echo ""
    
    # Get Istio ingress gateway info
    local gateway_ip=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    local gateway_hostname=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$gateway_ip" ]; then
        print_info "Istio Ingress Gateway IP: $gateway_ip"
    elif [ -n "$gateway_hostname" ]; then
        print_info "Istio Ingress Gateway Hostname: $gateway_hostname"
    else
        print_warning "Istio Ingress Gateway LoadBalancer IP/Hostname not available yet"
    fi
    
    echo ""
    print_info "To access Kubeflow via port-forward (for testing):"
    echo "  kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80"
    echo "  Then open: http://localhost:8080"
    echo ""
    
    print_info "Default credentials:"
    echo "  Email: user@example.com"
    echo "  Password: 12341234"
    echo ""
    
    print_warning "IMPORTANT: Change the default password before production use!"
    echo "  See README.md for instructions"
    echo ""
    
    print_info "For production access:"
    echo "  1. Configure your DNS to point to the Istio Ingress Gateway"
    echo "  2. Update the Gateway resource with your domain"
    echo "  3. Ensure TLS certificates are properly configured"
    echo ""
    
    print_info "Useful commands:"
    echo "  # Check all pods"
    echo "  kubectl get pods -A | grep -v Running | grep -v Completed"
    echo ""
    echo "  # View logs"
    echo "  kubectl logs -n kubeflow deployment/centraldashboard"
    echo ""
    echo "  # Check Istio configuration"
    echo "  kubectl get gateway,virtualservice -n kubeflow"
    echo ""
    
    print_info "Documentation: See README.md and CUSTOMIZATION.md"
}

# Main installation function
main() {
    echo ""
    print_info "========================================"
    print_info "  Kubeflow All-in-One Installer"
    print_info "========================================"
    echo ""
    
    # Check if we're in the right directory
    if [ ! -f "kustomization.yaml" ]; then
        print_error "kustomization.yaml not found. Please run this script from the kubeflow-all-in-one directory."
        exit 1
    fi
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Confirm installation
    print_warning "This will install Kubeflow on your cluster."
    read -p "Do you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Installation cancelled."
        exit 0
    fi
    echo ""
    
    # Apply manifests
    if ! apply_with_retry; then
        print_error "Installation failed. Please check the errors above."
        exit 1
    fi
    echo ""
    
    # Wait for critical components
    print_info "Waiting for critical components to be ready..."
    
    # Wait for auth namespace
    if kubectl get namespace auth >/dev/null 2>&1; then
        wait_for_pods "auth" 300 || true
    fi
    
    # Wait for oauth2-proxy namespace
    if kubectl get namespace oauth2-proxy >/dev/null 2>&1; then
        wait_for_pods "oauth2-proxy" 300 || true
    fi
    
    # Wait for knative-serving namespace
    if kubectl get namespace knative-serving >/dev/null 2>&1; then
        wait_for_pods "knative-serving" 300 || true
    fi
    
    echo ""
    
    # Show status
    show_status
    
    # Show access information
    show_access_info
}

# Handle script arguments
case "${1:-}" in
    --check-only)
        check_prerequisites
        exit 0
        ;;
    --status)
        show_status
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --check-only    Check prerequisites only"
        echo "  --status        Show deployment status"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "Without options, the script will install Kubeflow."
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

