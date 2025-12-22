#!/bin/bash
# Build script for chaos-broker container images

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEPLOYMENT_DIR="$SCRIPT_DIR/.."

echo "========================================="
echo "Building Chaos Broker Container Images"
echo "========================================="
echo ""

# Configuration
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-localhost:5000}"  # Default to local registry for OpenShift
HANDLER_IMAGE="${REGISTRY}/chaos-broker-handler:${IMAGE_TAG}"
ORCHESTRATOR_IMAGE="${REGISTRY}/chaos-broker-orchestrator:${IMAGE_TAG}"

echo "Configuration:"
echo "  Project Root: $PROJECT_ROOT"
echo "  Deployment Dir: $DEPLOYMENT_DIR"
echo "  Registry: $REGISTRY"
echo "  Image Tag: $IMAGE_TAG"
echo "  Handler Image: $HANDLER_IMAGE"
echo "  Orchestrator Image: $ORCHESTRATOR_IMAGE"
echo ""

# Build handler image
echo "Building handler image..."
cd "$PROJECT_ROOT"  # Build from project root for correct COPY paths
docker build \
  -f terraform/openshift_deployment/docker/Dockerfile \
  -t "$HANDLER_IMAGE" \
  -t "chaos-broker-handler:${IMAGE_TAG}" \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  .

echo ""
echo "Handler image built: $HANDLER_IMAGE"
echo ""

# Build orchestrator image
echo "Building orchestrator image..."
docker build \
  -f terraform/openshift_deployment/docker/Dockerfile.orchestrator \
  -t "$ORCHESTRATOR_IMAGE" \
  -t "chaos-broker-orchestrator:${IMAGE_TAG}" \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  .

echo ""
echo "Orchestrator image built: $ORCHESTRATOR_IMAGE"
echo ""

# Push to registry (optional, uncomment if needed)
# echo "Pushing images to registry..."
# docker push "$HANDLER_IMAGE"
# docker push "$ORCHESTRATOR_IMAGE"

echo "========================================="
echo "Build Complete!"
echo "========================================="
echo ""
echo "To push images to OpenShift internal registry:"
echo "  docker tag $HANDLER_IMAGE <openshift-registry>/chaos-broker/chaos-broker-handler:${IMAGE_TAG}"
echo "  docker push <openshift-registry>/chaos-broker/chaos-broker-handler:${IMAGE_TAG}"
echo ""
echo "Or import images directly:"
echo "  oc import-image chaos-broker-handler:latest --from=$HANDLER_IMAGE --confirm -n chaos-broker"

