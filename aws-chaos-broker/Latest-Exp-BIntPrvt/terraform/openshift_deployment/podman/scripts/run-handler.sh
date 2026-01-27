#!/bin/bash
# Run script for chaos-broker handler container using Podman

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PODMAN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-chaos-broker-handler}"
HANDLER_PORT="${HANDLER_PORT:-8080}"
IMAGE_NAME="chaos-broker-handler:${IMAGE_TAG}"

# Storage directories (create if they don't exist)
STORAGE_DIR="${STORAGE_DIR:-${HOME}/chaos-broker-storage}"
EXPERIMENTS_DIR="${STORAGE_DIR}/experiments"
JOURNALS_DIR="${STORAGE_DIR}/journals"

echo "========================================="
echo "Running Chaos Broker Handler Container"
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
    "$SCRIPT_DIR/build-images.sh" handler
fi

# Stop and remove existing container if it exists
if podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping existing container: $CONTAINER_NAME"
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
    echo "Removing existing container: $CONTAINER_NAME"
    podman rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Create storage directories
mkdir -p "$EXPERIMENTS_DIR" "$JOURNALS_DIR"
echo "Storage directories:"
echo "  Experiments: $EXPERIMENTS_DIR"
echo "  Journals: $JOURNALS_DIR"
echo ""

# Determine volume mount suffix based on OS
VOLUME_SUFFIX=""
if [[ "$(uname)" == "Linux" ]] && command -v getenforce &> /dev/null && [[ "$(getenforce)" == "Enforcing" ]]; then
    VOLUME_SUFFIX=":Z"  # SELinux labeling for RHEL/Fedora
fi

# Run container
echo "Starting container: $CONTAINER_NAME"
echo "  Image: $IMAGE_NAME"
echo "  Port: $HANDLER_PORT:8080"
echo ""

podman run -d \
    --name "$CONTAINER_NAME" \
    -p "${HANDLER_PORT}:8080" \
    -v "${EXPERIMENTS_DIR}:/app/local_only/experiments${VOLUME_SUFFIX}" \
    -v "${JOURNALS_DIR}:/app/local_only/journals${VOLUME_SUFFIX}" \
    -e local_mode=podman \
    -e PYTHONPATH=/app \
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
if curl -f -s "http://localhost:${HANDLER_PORT}/health" > /dev/null 2>&1; then
    echo "✓ Handler service is healthy"
    echo ""
    echo "Service endpoints:"
    echo "  Health: http://localhost:${HANDLER_PORT}/health"
    echo "  Invoke: POST http://localhost:${HANDLER_PORT}/invoke"
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

