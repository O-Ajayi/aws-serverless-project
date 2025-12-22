# OpenShift Local Setup Guide for macOS

This guide walks you through setting up an open-source OpenShift cluster on your local MacBook using CodeReady Containers (CRC) for testing the chaos-broker deployment.

## What is CRC?

CodeReady Containers (CRC) is a tool that runs a minimal OpenShift 4.x cluster on your local machine. It's perfect for development and testing without requiring cloud infrastructure.

## Prerequisites

- **macOS 10.15 or later** (Catalina, Big Sur, Monterey, Ventura, Sonoma)
- **8 GB RAM minimum** (16 GB recommended)
- **4 CPU cores minimum** (8 cores recommended)
- **35 GB free disk space**
- **Homebrew** installed
- **Virtualization support** (Intel VT-x or AMD-V)

## Step 1: Install Required Tools

### Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Install CRC (Red Hat OpenShift Local)

**⚠ Important**: The Homebrew tap `codereadycontainers/crc/crc` has been deprecated. Use one of the methods below:

**Option 1: Direct Download and Install (Recommended)**

```bash
# Download CRC installer
cd ~/Downloads
curl -LO https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/latest/crc-macos-installer.zip

# Unzip and install
unzip crc-macos-installer.zip
sudo installer -pkg crc-macos-installer/crc.pkg -target /

# Verify installation
crc version
```

**Alternative Methods**: See [OPENSHIFT_INSTALLATION.md](OPENSHIFT_INSTALLATION.md) for detailed installation options including manual binary installation and troubleshooting.

**Note**: If you're on Apple Silicon (M1/M2), CRC support is limited. You may need to use the podman preset which provides a more limited OpenShift experience.

### Install OpenShift CLI (oc)

```bash
# Install oc CLI using Homebrew
brew install openshift-cli

# Verify installation
oc version --client
```

### Install Podman or Docker

CRC can use either Podman or Docker Desktop. For macOS, Docker Desktop is easier:

```bash
# Install Docker Desktop
brew install --cask docker

# Start Docker Desktop from Applications or:
open -a Docker

# Verify Docker is running
docker ps
```

**Alternative: Install Podman**

```bash
# Install Podman using Homebrew
brew install podman

# Initialize Podman machine
podman machine init
podman machine start

# Verify Podman is running
podman ps
```

## Step 2: Setup CRC

### Pull CRC image

```bash
# Pull the CRC image (this downloads ~8 GB, takes 10-30 minutes)
crc setup
```

This command will:
- Download the OpenShift bundle
- Extract it to your system
- Configure the virtual machine

### Start CRC

```bash
# Start the CRC cluster
crc start

# Follow the prompts:
# - Enter pull secret (get from: https://console.redhat.com/openshift/create/local)
# - Choose memory allocation (default: 9216 MB)
# - Choose CPU cores (default: 4)
```

**Getting Pull Secret:**
1. Visit: https://console.redhat.com/openshift/create/local
2. Sign in or create a free Red Hat account
3. Copy the pull secret
4. Paste it when prompted by `crc start`

**Note**: The first start takes 5-15 minutes as it creates and configures the VM.

### Verify CRC is Running

```bash
# Check CRC status
crc status

# Expected output:
# CRC VM:          Running
# OpenShift:       Running (v4.x.x)
# Disk Usage:      X.X of XX.X GB (Inside the CRC VM)
# Cache Usage:     X.X GB
# Cache Directory: /Users/yourname/.crc/cache
```

## Step 3: Configure kubectl/oc CLI

### Login to the Cluster

```bash
# Get credentials
crc console --credentials

# Expected output:
# To login as a regular user, run 'oc login -u developer -p <password> https://api.crc.testing:6443'
# To login as an admin, run 'oc login -u kubeadmin -p <password> https://api.crc.testing:6443'

# Login as admin (for full cluster access)
oc login -u kubeadmin -p <password> https://api.crc.testing:6443
```

### Verify Cluster Access

```bash
# Check cluster info
oc cluster-info

# Check nodes
oc get nodes

# Check all namespaces
oc get namespaces
```

### Configure kubectl Context

```bash
# Set kubectl context to CRC
oc config set-cluster crc --server=https://api.crc.testing:6443 --insecure-skip-tls-verify=true

# View current context
kubectl config current-context

# Or use oc to switch context
oc config use-context crc-admin
```

## Step 4: Install Container Runtime (if needed)

CRC uses a bundled hypervisor, but you may need to configure container runtime access:

```bash
# If using Docker Desktop, ensure it's running
docker ps

# If using Podman, ensure it's initialized
podman machine start
```

## Step 5: Configure DNS (Optional but Recommended)

CRC provides a script to add cluster hostnames to `/etc/hosts`:

```bash
# Add CRC hostnames to /etc/hosts
crc oc-env | grep PATH
eval $(crc oc-env)

# The cluster should be accessible at:
# - API: https://api.crc.testing:6443
# - Console: https://console-openshift-console.apps-crc.testing
```

## Step 6: Access OpenShift Web Console

```bash
# Open the web console
crc console

# Or visit manually:
# URL: https://console-openshift-console.apps-crc.testing
# Username: kubeadmin
# Password: (from crc console --credentials)
```

## Step 7: Configure Storage for CRC

CRC doesn't have dynamic storage provisioning by default. You need to set up storage manually:

**Option 1: Create Test PersistentVolume (Easiest)**

Use the provided script:
```bash
cd terraform/openshift_deployment
./scripts/create-test-pv.sh
```

This creates a PV using hostPath pointing to `/tmp/chaos-broker-storage` on your Mac.

**Option 2: Install hostpath-provisioner Operator**

```bash
# Login as admin first
oc login -u kubeadmin -p <password> https://api.crc.testing:6443

# Apply hostpath-provisioner
oc apply -f https://raw.githubusercontent.com/openshift/hostpath-provisioner/main/release/hostpath-provisioner.yaml

# Or using the official operator:
# Create namespace
oc create namespace hostpath-provisioner

# Apply operator subscription
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: hostpath-provisioner
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/openshift/origin-hostpath-provisioner:latest
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hostpath-provisioner
  namespace: openshift-marketplace
spec:
  channel: stable
  name: hostpath-provisioner
  source: hostpath-provisioner
  sourceNamespace: openshift-marketplace
EOF
```

**Simpler Alternative: Use HostPath StorageClass**

```bash
# Create a simple hostpath storage class
cat <<EOF | oc apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hostpath
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
```

**Note**: For CRC, you may need to manually create PVs or use local storage. Update the PVC in manifests to use `storageClassName: hostpath` or remove it for default storage.

## Step 8: Verify Environment

### Check Cluster Resources

```bash
# Check cluster version
oc version

# Check available storage classes
oc get storageclass

# Check nodes and their resources
oc describe nodes

# Check default namespace
oc get all -n default
```

### Test Container Registry

```bash
# CRC includes a built-in registry
oc get route default-route -n openshift-image-registry

# Login to internal registry
oc registry login
```

## Step 9: Deploy Chaos Broker

Now you're ready to deploy the chaos-broker to your local OpenShift cluster!

```bash
# Navigate to deployment directory
cd terraform/openshift_deployment

# Build container images
./scripts/build-images.sh

# Import images to CRC's internal registry
# Get registry route
REGISTRY=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}')

# Login to registry
docker login -u kubeadmin -p $(oc whoami -t) $REGISTRY

# Tag and push images
docker tag chaos-broker-handler:latest $REGISTRY/chaos-broker/chaos-broker-handler:latest
docker tag chaos-broker-orchestrator:latest $REGISTRY/chaos-broker/chaos-broker-orchestrator:latest

docker push $REGISTRY/chaos-broker/chaos-broker-handler:latest
docker push $REGISTRY/chaos-broker/chaos-broker-orchestrator:latest

# Or use CRC's local registry directly
# Tag images for CRC
docker tag chaos-broker-handler:latest default-route-openshift-image-registry.apps-crc.testing/chaos-broker/chaos-broker-handler:latest
docker tag chaos-broker-orchestrator:latest default-route-openshift-image-registry.apps-crc.testing/chaos-broker/chaos-broker-orchestrator:latest

# Push to CRC registry
docker push default-route-openshift-image-registry.apps-crc.testing/chaos-broker/chaos-broker-handler:latest
docker push default-route-openshift-image-registry.apps-crc.testing/chaos-broker/chaos-broker-orchestrator:latest

# Deploy using kubectl/oc
./scripts/deploy.sh

# Or deploy using Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with:
# - handler_image: default-route-openshift-image-registry.apps-crc.testing/chaos-broker/chaos-broker-handler:latest
# - orchestrator_image: default-route-openshift-image-registry.apps-crc.testing/chaos-broker/chaos-broker-orchestrator:latest
# - storage_class: hostpath (or empty for default)

terraform init
terraform apply
```

## Step 10: Troubleshooting Common Issues

### CRC Won't Start

```bash
# Check system requirements
crc setup --check-only

# Reset CRC
crc stop
crc delete
crc setup
crc start
```

### Out of Memory

```bash
# Check CRC memory allocation
crc config view

# Increase memory (if you have RAM available)
crc config set memory 16384  # 16 GB
crc stop
crc start
```

### DNS Issues

```bash
# Add CRC domains to /etc/hosts manually
sudo vim /etc/hosts

# Add these lines:
# 192.168.130.11 api.crc.testing
# 192.168.130.11 console-openshift-console.apps-crc.testing
# 192.168.130.11 default-route-openshift-image-registry.apps-crc.testing
```

### Storage Issues

```bash
# Check available storage
crc status

# If PVCs are stuck in Pending:
# Option 1: Use emptyDir (temporary, no persistence)
# Option 2: Create manual PVs for hostpath storage
# Option 3: Use the simpler storage class configuration above
```

### Cannot Push Images to Registry

```bash
# Ensure registry route exists
oc get route default-route -n openshift-image-registry

# Expose registry externally
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

# Get registry URL
oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}'

# Login
docker login -u kubeadmin -p $(oc whoami -t) default-route-openshift-image-registry.apps-crc.testing
```

### Pods Stuck in ImagePullBackOff

```bash
# Check image pull secrets
oc get secrets -n chaos-broker

# Create pull secret for internal registry
oc create secret docker-registry registry-secret \
  --docker-server=default-route-openshift-image-registry.apps-crc.testing \
  --docker-username=kubeadmin \
  --docker-password=$(oc whoami -t) \
  -n chaos-broker

# Patch service account to use the secret
oc patch serviceaccount default -n chaos-broker -p '{"imagePullSecrets": [{"name": "registry-secret"}]}'
```

## Step 11: Useful CRC Commands

```bash
# Check status
crc status

# Start cluster
crc start

# Stop cluster
crc stop

# Delete cluster (keeps VM)
crc delete

# Clean everything (deletes VM too)
crc cleanup

# Get console credentials
crc console --credentials

# Open web console
crc console

# View logs
crc logs

# Get oc environment
crc oc-env

# Configure settings
crc config view
crc config set memory 16384
crc config set cpus 8
```

## Step 12: Alternative: Using minikube with OpenShift (Not Recommended)

If CRC doesn't work for you, you can use minikube with OpenShift-like features, but it's not a true OpenShift cluster:

```bash
# Install minikube
brew install minikube

# Start minikube with enough resources
minikube start --memory=8192 --cpus=4

# Install OpenShift-like components manually (complex)
```

**Recommendation**: Stick with CRC for the best OpenShift experience.

## Step 13: Next Steps

Once your cluster is running:

1. **Follow the deployment guide**: See [README.md](README.md)
2. **Upload experiment files**: Use `./scripts/upload-experiment.sh`
3. **Test the workflow**: See [WORKFLOW.md](WORKFLOW.md)
4. **Monitor resources**: Use `oc get all -n chaos-broker`

## Resource Requirements Summary

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 8 GB | 16 GB |
| CPU Cores | 4 | 8 |
| Disk Space | 35 GB | 50 GB |
| Network | Internet for pull | Stable connection |

## Getting Help

- **CRC Documentation**: https://crc.dev/crc/
- **OpenShift Documentation**: https://docs.openshift.com/
- **CRC GitHub Issues**: https://github.com/crc-org/crc/issues

## Quick Reference

```bash
# Complete setup from scratch
brew install codereadycontainers/crc/crc openshift-cli
brew install --cask docker
crc setup
crc start
oc login -u kubeadmin -p <password> https://api.crc.testing:6443

# Deploy chaos-broker
cd terraform/openshift_deployment
./scripts/build-images.sh
# (Push images to registry)
./scripts/deploy.sh
```

---

**Note**: CRC is intended for development and testing. It's not suitable for production workloads.

