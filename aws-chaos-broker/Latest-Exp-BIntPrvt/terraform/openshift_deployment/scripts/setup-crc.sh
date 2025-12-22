#!/bin/bash
# Automated setup script for CRC (CodeReady Containers) on macOS

set -e

echo "========================================="
echo "CRC (CodeReady Containers) Setup Script"
echo "========================================="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script is for macOS only"
    exit 1
fi

# Check Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Step 1: Installing required tools..."
echo ""

# Install CRC
if ! command -v crc &> /dev/null; then
    echo "Installing CRC..."
    echo ""
    echo "The Homebrew tap for CRC has changed. Trying alternative methods..."
    echo ""
    
    # Try new tap location
    if brew tap redhat-developer/redhat-developer 2>/dev/null; then
        echo "Using redhat-developer tap..."
        brew install crc
    elif brew install --cask crc 2>/dev/null; then
        echo "Installed via cask..."
    else
        echo ""
        echo "⚠ Homebrew installation failed. Please install CRC manually:"
        echo ""
        echo "Option 1: Direct download (recommended):"
        echo "  1. Visit: https://developers.redhat.com/products/openshift-local/download"
        echo "  2. Download CRC for macOS"
        echo "  3. Install the .pkg file"
        echo ""
        echo "Option 2: Manual binary installation:"
        echo "  cd /tmp"
        echo "  curl -LO https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/latest/crc-macos-amd64-installer.zip"
        echo "  unzip crc-macos-amd64-installer.zip"
        echo "  sudo mv crc-macos-amd64-installer/crc /usr/local/bin/"
        echo "  sudo chmod +x /usr/local/bin/crc"
        echo ""
        read -p "Press Enter after installing CRC manually, or Ctrl+C to exit..."
    fi
fi

if command -v crc &> /dev/null; then
    echo "✓ CRC installed successfully"
    crc version
else
    echo "✗ CRC installation failed or not found in PATH"
    exit 1
fi

# Install OpenShift CLI
if ! command -v oc &> /dev/null; then
    echo "Installing OpenShift CLI (oc)..."
    brew install openshift-cli
else
    echo "✓ OpenShift CLI already installed"
    oc version --client
fi

# Check Docker/Podman
if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
    echo "Installing Docker Desktop..."
    brew install --cask docker
    echo "⚠ Please start Docker Desktop manually:"
    echo "   open -a Docker"
    echo "   Then run this script again"
    exit 1
elif command -v docker &> /dev/null; then
    echo "✓ Docker found"
    if ! docker ps &> /dev/null; then
        echo "⚠ Docker is not running. Starting Docker..."
        open -a Docker
        echo "   Waiting for Docker to start..."
        sleep 10
    fi
else
    echo "✓ Podman found"
fi

echo ""
echo "Step 2: Setting up CRC..."
echo ""

# Check if CRC is already set up
if crc status &> /dev/null; then
    echo "✓ CRC is already set up and running"
    crc status
else
    echo "Running crc setup (this downloads ~8 GB and takes 10-30 minutes)..."
    echo "⚠ This is a one-time setup. Please be patient."
    crc setup
fi

echo ""
echo "Step 3: Starting CRC..."
echo ""

# Check if CRC is running
if crc status 2>/dev/null | grep -q "Running"; then
    echo "✓ CRC is already running"
else
    echo "Starting CRC..."
    echo "⚠ You will be prompted for:"
    echo "   1. Pull secret from: https://console.redhat.com/openshift/create/local"
    echo "   2. Memory allocation (default: 9216 MB)"
    echo "   3. CPU cores (default: 4)"
    echo ""
    read -p "Press Enter to continue with crc start..."
    crc start
fi

echo ""
echo "Step 4: Configuring OpenShift CLI..."
echo ""

# Get credentials and login
echo "Getting cluster credentials..."
CREDENTIALS=$(crc console --credentials)

# Extract password
PASSWORD=$(echo "$CREDENTIALS" | grep -oP 'kubeadmin.*password:\s*\K[^\s]+' || echo "")

if [ -z "$PASSWORD" ]; then
    echo "⚠ Could not extract password automatically"
    echo "Please run manually:"
    echo "  crc console --credentials"
    echo "  oc login -u kubeadmin -p <password> https://api.crc.testing:6443"
else
    echo "Logging in to cluster..."
    oc login -u kubeadmin -p "$PASSWORD" https://api.crc.testing:6443 --insecure-skip-tls-verify=true || {
        echo "⚠ Login failed. Please login manually:"
        echo "  oc login -u kubeadmin -p <password> https://api.crc.testing:6443"
    }
fi

echo ""
echo "Step 5: Verifying cluster..."
echo ""

# Verify cluster access
if oc cluster-info &> /dev/null; then
    echo "✓ Successfully connected to cluster"
    echo ""
    echo "Cluster Information:"
    oc cluster-info
    echo ""
    echo "Nodes:"
    oc get nodes
    echo ""
    echo "Namespaces:"
    oc get namespaces
else
    echo "⚠ Could not verify cluster access"
    echo "Please verify manually:"
    echo "  oc cluster-info"
fi

echo ""
echo "Step 6: Configuring storage..."
echo ""

# Check if hostpath storage class exists
if oc get storageclass hostpath &> /dev/null; then
    echo "✓ HostPath storage class already exists"
else
    echo "Creating HostPath storage class..."
    cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hostpath
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
    echo "✓ HostPath storage class created"
fi

echo ""
echo "========================================="
echo "CRC Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Deploy chaos-broker:"
echo "     cd terraform/openshift_deployment"
echo "     ./scripts/build-images.sh"
echo "     ./scripts/deploy.sh"
echo ""
echo "  2. Access web console:"
echo "     crc console"
echo ""
echo "  3. Get credentials anytime:"
echo "     crc console --credentials"
echo ""
echo "Useful commands:"
echo "  crc status          - Check cluster status"
echo "  crc stop            - Stop cluster"
echo "  crc start           - Start cluster"
echo "  crc console         - Open web console"
echo "  oc get all          - List all resources"
echo ""

