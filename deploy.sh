#!/bin/bash
# Deployment script for Minecraft Helm chart

set -e

# Configuration
CHART_DIR="./chart"
RELEASE_NAME="${RELEASE_NAME:-minecraft-server}"
NAMESPACE="${NAMESPACE:-default}"
VALUES_FILE="${VALUES_FILE:-}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if helm is installed
check_helm() {
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    log_info "Helm version: $(helm version --short)"
}

# Check if kubectl is available and connected
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "kubectl is not connected to a cluster. Please configure your kubeconfig."
        exit 1
    fi
    
    log_info "Connected to cluster: $(kubectl config current-context)"
}

# Create namespace if it doesn't exist
create_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Creating namespace: $NAMESPACE"
        kubectl create namespace "$NAMESPACE"
    else
        log_info "Namespace $NAMESPACE already exists"
    fi
}

# Validate chart
validate_chart() {
    log_info "Validating Helm chart..."
    helm lint "$CHART_DIR"
    
    if [ $? -eq 0 ]; then
        log_info "Chart validation passed"
    else
        log_error "Chart validation failed"
        exit 1
    fi
}

# Deploy or upgrade
deploy() {
    local cmd_args=()
    
    # Add namespace
    cmd_args+=("--namespace" "$NAMESPACE")
    
    # Add values file if provided
    if [ -n "$VALUES_FILE" ]; then
        if [ -f "$VALUES_FILE" ]; then
            cmd_args+=("--values" "$VALUES_FILE")
            log_info "Using values file: $VALUES_FILE"
        else
            log_error "Values file not found: $VALUES_FILE"
            exit 1
        fi
    fi
    
    # Add dry-run if enabled
    if [ "$DRY_RUN" = "true" ]; then
        cmd_args+=("--dry-run")
        log_info "Running in dry-run mode"
    fi
    
    # Check if release exists
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        log_info "Upgrading existing release: $RELEASE_NAME"
        helm upgrade "$RELEASE_NAME" "$CHART_DIR" "${cmd_args[@]}"
    else
        log_info "Installing new release: $RELEASE_NAME"
        helm install "$RELEASE_NAME" "$CHART_DIR" "${cmd_args[@]}"
    fi
}

# Show status
show_status() {
    if [ "$DRY_RUN" != "true" ]; then
        log_info "Deployment status:"
        helm status "$RELEASE_NAME" -n "$NAMESPACE"
        
        log_info "Waiting for deployment to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/"$RELEASE_NAME" -n "$NAMESPACE"
        
        log_info "Getting service information..."
        kubectl get svc "$RELEASE_NAME" -n "$NAMESPACE"
    fi
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Minecraft server using Helm chart.

Options:
    -n, --namespace NAMESPACE     Kubernetes namespace (default: default)
    -r, --release RELEASE_NAME    Helm release name (default: minecraft-server)
    -f, --values VALUES_FILE      Values file to use
    -d, --dry-run                 Run in dry-run mode
    -h, --help                    Show this help

Examples:
    # Deploy with default values
    $0

    # Deploy to specific namespace
    $0 -n minecraft

    # Deploy with custom values
    $0 -f values-production.yaml

    # Deploy with custom release name and namespace
    $0 -r my-server -n minecraft-ns

    # Dry run with production values
    $0 -f values-production.yaml -d

Environment variables:
    RELEASE_NAME    Helm release name
    NAMESPACE       Kubernetes namespace
    VALUES_FILE     Path to values file
    DRY_RUN         Set to "true" for dry-run mode

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Starting Minecraft server deployment..."
    log_info "Release: $RELEASE_NAME"
    log_info "Namespace: $NAMESPACE"
    
    check_helm
    check_kubectl
    validate_chart
    create_namespace
    deploy
    show_status
    
    log_info "Deployment completed successfully!"
    
    if [ "$DRY_RUN" != "true" ]; then
        log_info ""
        log_info "To get connection information, run:"
        log_info "  helm status $RELEASE_NAME -n $NAMESPACE"
        log_info ""
        log_info "To view logs, run:"
        log_info "  kubectl logs -f deployment/$RELEASE_NAME -n $NAMESPACE"
    fi
}

# Run main function
main
