#!/bin/bash
# Cleanup script for chaos-broker Podman containers and images

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
REMOVE_IMAGES="${REMOVE_IMAGES:-false}"
REMOVE_VOLUMES="${REMOVE_VOLUMES:-false}"
STORAGE_DIR="${STORAGE_DIR:-${HOME}/chaos-broker-storage}"

CONTAINERS=(
    "chaos-broker-handler"
    "chaos-broker-orchestrator"
)

IMAGES=(
    "chaos-broker-handler:latest"
    "chaos-broker-orchestrator:latest"
)

echo "========================================="
echo "Cleaning up Chaos Broker Podman Resources"
echo "========================================="
echo ""

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is not installed"
    exit 1
fi

# Stop and remove containers
echo "Stopping and removing containers..."
for container in "${CONTAINERS[@]}"; do
    if podman ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "  Stopping: $container"
        podman stop "$container" 2>/dev/null || true
        echo "  Removing: $container"
        podman rm "$container" 2>/dev/null || true
    else
        echo "  Container not found: $container"
    fi
done
echo ""

# Remove images (optional)
if [ "$REMOVE_IMAGES" = "true" ]; then
    echo "Removing images..."
    for image in "${IMAGES[@]}"; do
        if podman images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${image}$"; then
            echo "  Removing: $image"
            podman rmi "$image" 2>/dev/null || true
        else
            echo "  Image not found: $image"
        fi
    done
    echo ""
else
    echo "Images preserved (set REMOVE_IMAGES=true to remove)"
    echo "  To remove images: REMOVE_IMAGES=true ./scripts/cleanup.sh"
    echo ""
fi

# Remove storage directories (optional)
if [ "$REMOVE_VOLUMES" = "true" ]; then
    echo "Removing storage directories..."
    if [ -d "$STORAGE_DIR" ]; then
        echo "  Removing: $STORAGE_DIR"
        rm -rf "$STORAGE_DIR"
    else
        echo "  Storage directory not found: $STORAGE_DIR"
    fi
    echo ""
else
    echo "Storage directories preserved (set REMOVE_VOLUMES=true to remove)"
    echo "  Storage directory: $STORAGE_DIR"
    echo "  To remove storage: REMOVE_VOLUMES=true ./scripts/cleanup.sh"
    echo ""
fi

echo "========================================="
echo "Cleanup Complete!"
echo "========================================="
echo ""

# Show remaining resources
echo "Remaining containers:"
podman ps -a | grep chaos-broker || echo "  No chaos-broker containers found"
echo ""

echo "Remaining images:"
podman images | grep chaos-broker || echo "  No chaos-broker images found"
echo ""

