#!/bin/bash
# Build script for chaos-broker container images using Podman

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PODMAN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOYMENT_DIR="$(cd "$PODMAN_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$DEPLOYMENT_DIR/../.." && pwd)"

echo "========================================="
echo "Building Chaos Broker Container Images with Podman"
echo "========================================="
echo ""

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is not installed"
    echo "Install Podman: https://podman.io/getting-started/installation"
    exit 1
fi

# Check if Podman machine is running (macOS)
# On macOS, Podman requires a machine/VM to be running
if [[ "$(uname)" == "Darwin" ]]; then
    if ! podman info &> /dev/null; then
        echo "Error: Cannot connect to Podman"
        echo ""
        echo "On macOS, Podman requires a machine to be running."
        echo ""
        echo "Check machine status:"
        echo "  podman machine list"
        echo ""
        echo "If no machine exists, initialize one:"
        echo "  podman machine init"
        echo ""
        echo "Start the machine:"
        echo "  podman machine start"
        echo ""
        echo "Then try running this script again."
        exit 1
    fi
fi

# Configuration
IMAGE_TAG="${IMAGE_TAG:-latest}"
COMPONENT="${1:-all}"  # all, handler, orchestrator

HANDLER_IMAGE="chaos-broker-handler:${IMAGE_TAG}"
ORCHESTRATOR_IMAGE="chaos-broker-orchestrator:${IMAGE_TAG}"

echo "Configuration:"
echo "  Project Root: $PROJECT_ROOT"
echo "  Deployment Dir: $DEPLOYMENT_DIR"
echo "  Image Tag: $IMAGE_TAG"
echo "  Component: $COMPONENT"
echo "  Handler Image: $HANDLER_IMAGE"
echo "  Orchestrator Image: $ORCHESTRATOR_IMAGE"
echo ""

# Function to build handler image
build_handler() {
    echo "Building handler image..."
    cd "$PROJECT_ROOT"  # Build from project root for correct COPY paths
    
    podman build \
        -f terraform/openshift_deployment/docker/Dockerfile \
        -t "$HANDLER_IMAGE" \
        .
    
    echo ""
    echo "Handler image built: $HANDLER_IMAGE"
    echo "  Image ID: $(podman images --format '{{.ID}}' $HANDLER_IMAGE | head -1)"
    echo ""
}

# Function to build orchestrator image
build_orchestrator() {
    echo "Building orchestrator image..."
    cd "$PROJECT_ROOT"  # Build from project root for correct COPY paths
    
    podman build \
        -f terraform/openshift_deployment/docker/Dockerfile.orchestrator \
        -t "$ORCHESTRATOR_IMAGE" \
        .
    
    echo ""
    echo "Orchestrator image built: $ORCHESTRATOR_IMAGE"
    echo "  Image ID: $(podman images --format '{{.ID}}' $ORCHESTRATOR_IMAGE | head -1)"
    echo ""
}

# Build based on component
case "$COMPONENT" in
    handler)
        build_handler
        ;;
    orchestrator)
        build_orchestrator
        ;;
    all)
        build_handler
        build_orchestrator
        ;;
    *)
        echo "Error: Invalid component '$COMPONENT'"
        echo "Valid options: all, handler, orchestrator"
        exit 1
        ;;
esac

echo "========================================="
echo "Build Complete!"
echo "========================================="
echo ""
echo "Built images:"
podman images | grep chaos-broker || echo "No chaos-broker images found"
echo ""
echo "To run containers:"
echo "  Handler: ./scripts/run-handler.sh"
echo "  Orchestrator: ./scripts/run-orchestrator.sh"
echo ""
echo "To push images to a registry:"
echo "  podman tag $HANDLER_IMAGE <registry>/chaos-broker-handler:${IMAGE_TAG}"
echo "  podman push <registry>/chaos-broker-handler:${IMAGE_TAG}"
echo ""

