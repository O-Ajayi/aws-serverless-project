#!/bin/bash
# Run script for chaos-broker orchestrator container using Podman

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PODMAN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-chaos-broker-orchestrator}"
ORCHESTRATOR_PORT="${ORCHESTRATOR_PORT:-8081}"
HANDLER_URL="${HANDLER_URL:-http://host.containers.internal:8080}"
IMAGE_NAME="chaos-broker-orchestrator:${IMAGE_TAG}"

echo "========================================="
echo "Running Chaos Broker Orchestrator Container"
echo "========================================="
echo ""

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is not installed"
    echo "Install Podman: https://podman.io/getting-started/installation"
    exit 1
fi

# Check if Podman machine is running (macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    if ! podman info &> /dev/null; then
        echo "Error: Cannot connect to Podman"
        echo ""
        echo "On macOS, Podman requires a machine to be running."
        echo "Start the machine with: podman machine start"
        exit 1
    fi
fi

# Check if image exists
if ! podman images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
    echo "Image $IMAGE_NAME not found. Building..."
    "$SCRIPT_DIR/build-images.sh" orchestrator
fi

# Stop and remove existing container if it exists
if podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping existing container: $CONTAINER_NAME"
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    echo "Removing existing container: $CONTAINER_NAME"
    podman rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Determine handler URL based on OS and container setup
if [[ "$(uname)" == "Linux" ]]; then
    # On Linux, try to use host IP from container
    HANDLER_URL="${HANDLER_URL:-http://172.17.0.1:8080}"
fi

# Check if handler container is running (optional)
if podman ps --format '{{.Names}}' | grep -q "chaos-broker-handler"; then
    echo "✓ Handler container detected"
else
    echo "⚠ Warning: Handler container not found"
    echo "  Make sure handler is running or HANDLER_URL is correct"
    echo "  Current HANDLER_URL: $HANDLER_URL"
fi
echo ""

# Run container
echo "Starting container: $CONTAINER_NAME"
echo "  Image: $IMAGE_NAME"
echo "  Port: $ORCHESTRATOR_PORT:8081"
echo "  Handler URL: $HANDLER_URL"
echo ""

podman run -d \
    --name "$CONTAINER_NAME" \
    -p "${ORCHESTRATOR_PORT}:8081" \
    -e HANDLER_SERVICE_URL="$HANDLER_URL" \
    -e PYTHONPATH=/app \
    -e LOG_LEVEL=INFO \
    -e ORCHESTRATOR_PORT=8081 \
    "$IMAGE_NAME"

echo "Container started: $CONTAINER_NAME"
echo ""
echo "Container status:"
podman ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Wait for container to be ready
echo "Waiting for service to be ready..."
sleep 3

# Check health
if curl -f -s "http://localhost:${ORCHESTRATOR_PORT}/health" > /dev/null 2>&1; then
    echo "✓ Orchestrator service is healthy"
    echo ""
    echo "Service endpoints:"
    echo "  Health: http://localhost:${ORCHESTRATOR_PORT}/health"
    echo "  Execute: POST http://localhost:${ORCHESTRATOR_PORT}/execute"
    echo ""
else
    echo "⚠ Service may not be ready yet. Check logs with:"
    echo "  podman logs $CONTAINER_NAME"
    echo ""
fi

echo "Useful commands:"
echo "  View logs: podman logs -f $CONTAINER_NAME"
echo "  Stop container: podman stop $CONTAINER_NAME"
echo "  Remove container: podman rm $CONTAINER_NAME"
echo "  Shell into container: podman exec -it $CONTAINER_NAME /bin/bash"
echo ""
echo "To use with a custom network:"
echo "  podman network create chaos-broker-net"
echo "  Run handler and orchestrator with: --network chaos-broker-net"
echo "  Use container name in HANDLER_URL: http://chaos-broker-handler:8080"
echo ""

