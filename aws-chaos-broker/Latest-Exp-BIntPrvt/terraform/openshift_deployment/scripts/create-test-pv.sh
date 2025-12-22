#!/bin/bash
# Script to create a test PersistentVolume for CRC/local OpenShift
# This is needed because CRC doesn't have dynamic provisioning by default

set -e

NAMESPACE="${NAMESPACE:-chaos-broker}"
PVC_NAME="${PVC_NAME:-chaos-broker-storage}"
PV_NAME="${PV_NAME:-chaos-broker-pv}"
STORAGE_SIZE="${STORAGE_SIZE:-10Gi}"
STORAGE_PATH="${STORAGE_PATH:-/tmp/chaos-broker-storage}"

echo "Creating test PersistentVolume for CRC/local OpenShift..."
echo "Namespace: $NAMESPACE"
echo "PVC Name: $PVC_NAME"
echo "PV Name: $PV_NAME"
echo "Storage Size: $STORAGE_SIZE"
echo "Storage Path: $STORAGE_PATH"
echo ""

# Check if oc is available
if ! command -v oc &> /dev/null; then
    echo "Error: oc command not found. Please install OpenShift CLI"
    exit 1
fi

# Login check
if ! oc whoami &> /dev/null; then
    echo "Error: Not logged in to cluster"
    echo "Please login first: oc login -u kubeadmin -p <password> https://api.crc.testing:6443"
    exit 1
fi

# Create namespace if it doesn't exist
if ! oc get namespace "$NAMESPACE" &> /dev/null; then
    echo "Creating namespace: $NAMESPACE"
    oc create namespace "$NAMESPACE"
fi

# Create storage directory on host
echo "Creating storage directory: $STORAGE_PATH"
mkdir -p "$STORAGE_PATH"
chmod 777 "$STORAGE_PATH"

# Create PersistentVolume
echo "Creating PersistentVolume: $PV_NAME"
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $PV_NAME
  labels:
    type: local
spec:
  storageClassName: hostpath
  capacity:
    storage: $STORAGE_SIZE
  accessModes:
    - ReadWriteMany
  hostPath:
    path: $STORAGE_PATH
  persistentVolumeReclaimPolicy: Retain
  claimRef:
    name: $PVC_NAME
    namespace: $NAMESPACE
EOF

# Create PersistentVolumeClaim
echo "Creating PersistentVolumeClaim: $PVC_NAME"
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PVC_NAME
  namespace: $NAMESPACE
  labels:
    app: chaos-broker
spec:
  storageClassName: hostpath
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: $STORAGE_SIZE
EOF

# Wait for PVC to bind
echo "Waiting for PVC to bind..."
sleep 2

# Check status
oc get pv "$PV_NAME"
oc get pvc "$PVC_NAME" -n "$NAMESPACE"

echo ""
echo "✓ PersistentVolume and PVC created successfully"
echo ""
echo "Storage location: $STORAGE_PATH"
echo "To clean up:"
echo "  oc delete pvc $PVC_NAME -n $NAMESPACE"
echo "  oc delete pv $PV_NAME"
echo "  rm -rf $STORAGE_PATH"

