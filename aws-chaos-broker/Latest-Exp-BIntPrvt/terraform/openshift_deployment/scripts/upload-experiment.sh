#!/bin/bash
# Script to upload experiment YAML files to the persistent volume

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-chaos-broker}"
EXPERIMENTS_DIR="/app/local_only/experiments"

# Check if file argument provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <experiment-file.yaml> [experiment-file2.yaml ...]"
    echo ""
    echo "Uploads experiment YAML files to the persistent volume in the handler pod."
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/experiment.yaml"
    echo "  $0 experiment1.yaml experiment2.yaml"
    echo ""
    echo "Environment variables:"
    echo "  NAMESPACE: Kubernetes namespace (default: chaos-broker)"
    exit 1
fi

# Get handler pod name
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l component=handler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || oc get pods -n "$NAMESPACE" -l component=handler -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "Error: No handler pod found in namespace '$NAMESPACE'"
    echo "Make sure the handler service is deployed and running"
    exit 1
fi

echo "Uploading experiment files to handler pod: $POD_NAME"
echo "Namespace: $NAMESPACE"
echo "Destination: $EXPERIMENTS_DIR"
echo ""

# Upload each file
for file in "$@"; do
    if [ ! -f "$file" ]; then
        echo "Warning: File not found: $file (skipping)"
        continue
    fi
    
    filename=$(basename "$file")
    echo "Uploading $file -> $EXPERIMENTS_DIR/$filename ..."
    
    # Copy file to pod
    kubectl cp "$file" "$NAMESPACE/$POD_NAME:$EXPERIMENTS_DIR/$filename" 2>/dev/null || \
    oc cp "$file" "$NAMESPACE/$POD_NAME:$EXPERIMENTS_DIR/$filename" 2>/dev/null || {
        echo "Error: Failed to upload $file"
        exit 1
    }
    
    echo "✓ Successfully uploaded: $filename"
done

echo ""
echo "Files uploaded. Verify with:"
echo "  kubectl exec -n $NAMESPACE $POD_NAME -- ls -la $EXPERIMENTS_DIR"
echo ""
echo "Now you can reference these files in your orchestrator payload:"
echo "  \"experiment_source\": \"$filename\""

