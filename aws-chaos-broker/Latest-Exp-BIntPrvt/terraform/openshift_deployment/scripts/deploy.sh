#!/bin/bash
# Deployment script for chaos-broker on OpenShift

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$DEPLOYMENT_DIR/terraform"
MANIFESTS_DIR="$DEPLOYMENT_DIR/manifests"

echo "========================================="
echo "Deploying Chaos Broker to OpenShift"
echo "========================================="
echo ""

# Check for kubectl/oc
if command -v oc &> /dev/null; then
    KUBECTL="oc"
    echo "Using OpenShift CLI (oc)"
elif command -v kubectl &> /dev/null; then
    KUBECTL="kubectl"
    echo "Using Kubernetes CLI (kubectl)"
else
    echo "Error: Neither 'oc' nor 'kubectl' found in PATH"
    exit 1
fi

# Option 1: Deploy using Terraform
if [ "$1" == "terraform" ]; then
    echo "Deploying using Terraform..."
    cd "$TERRAFORM_DIR"
    
    if [ ! -f "terraform.tfvars" ]; then
        echo "Warning: terraform.tfvars not found, using defaults"
        echo "Copy terraform.tfvars.example to terraform.tfvars and customize as needed"
    fi
    
    terraform init
    terraform plan
    terraform apply -auto-approve
    
    echo ""
    echo "Terraform deployment complete!"
    echo ""
    echo "Get handler service URL:"
    echo "  terraform output handler_service_url"

# Option 2: Deploy using kubectl/oc
else
    echo "Deploying using kubectl/oc manifests..."
    
    # Create namespace
    echo "Creating namespace..."
    $KUBECTL apply -f "$MANIFESTS_DIR/namespace.yaml"
    
    # Apply manifests in order
    echo "Applying ConfigMap..."
    $KUBECTL apply -f "$MANIFESTS_DIR/configmap.yaml"
    
    echo "Creating PersistentVolumeClaim..."
    $KUBECTL apply -f "$MANIFESTS_DIR/persistent-volume-claim.yaml"
    
    echo "Deploying handler service..."
    $KUBECTL apply -f "$MANIFESTS_DIR/deployment-handler.yaml"
    $KUBECTL apply -f "$MANIFESTS_DIR/service-handler.yaml"
    
    echo "Deploying orchestrator service..."
    $KUBECTL apply -f "$MANIFESTS_DIR/deployment-orchestrator.yaml"
    $KUBECTL apply -f "$MANIFESTS_DIR/service-orchestrator.yaml"
    
    # Create route if using OpenShift
    if [ "$KUBECTL" == "oc" ]; then
        echo "Creating OpenShift Route..."
        $KUBECTL apply -f "$MANIFESTS_DIR/route-handler.yaml"
        
        echo ""
        echo "Route created. Get URL with:"
        echo "  oc get route chaos-broker-handler -n chaos-broker"
    fi
    
    echo ""
    echo "Deployment complete!"
    echo ""
    echo "Check status:"
    echo "  $KUBECTL get pods -n chaos-broker"
    echo "  $KUBECTL get svc -n chaos-broker"
fi

echo ""
echo "To test the handler service:"
echo "  $KUBECTL port-forward -n chaos-broker svc/chaos-broker-handler 8080:8080"
echo "  curl http://localhost:8080/health"

