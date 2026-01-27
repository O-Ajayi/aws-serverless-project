# Chaos Broker OpenShift Deployment

This directory contains everything needed to deploy the chaos-broker handler and orchestrator (Step Functions replacement) as containers on OpenShift running locally on your MacBook.

## Architecture Overview

The solution replaces AWS Lambda and Step Functions with:

1. **Handler Service**: HTTP service wrapping the `handler.py` module (replaces Lambda)
2. **Orchestrator Service**: Python-based workflow orchestrator (replaces Step Functions)
3. **OpenShift/Kubernetes**: Container orchestration platform

### Components

- **Handler Service**: Exposes the handler function via REST API (`POST /invoke`)
- **Orchestrator**: Implements the Step Functions state machine logic in Python
- **Persistent Storage**: PVC for storing experiments and journals
- **ConfigMap**: Configuration for both services

## Prerequisites

### Local OpenShift Setup

**Option 1: Automated Setup (Recommended)**

```bash
# Run the automated setup script
cd terraform/openshift_deployment
./scripts/setup-crc.sh
```

**Option 2: Manual Setup**

See the comprehensive guide: [OPENSHIFT_LOCAL_SETUP.md](OPENSHIFT_LOCAL_SETUP.md)

**Quick Manual Steps:**

1. **Install CRC (CodeReady Containers)**:
   
   **⚠ Note**: The Homebrew tap `codereadycontainers/crc/crc` is deprecated. Use direct download instead:
   
   ```bash
   # Download and install CRC directly
   cd ~/Downloads
   curl -LO https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/latest/crc-macos-installer.zip
   unzip crc-macos-installer.zip
   sudo installer -pkg crc-macos-installer/crc.pkg -target /
   
   # Verify installation
   crc version
   
   # Setup CRC (downloads ~8 GB)
   crc setup
   
   # Start CRC
   crc start
   # Follow prompts to enter pull secret from:
   # https://console.redhat.com/openshift/create/local
   
   # Get credentials
   crc console --credentials
   
   # Login
   oc login -u kubeadmin -p <password> https://api.crc.testing:6443
   ```

2. **Install Required Tools**:
   ```bash
   # OpenShift CLI
   brew install openshift-cli
   
   # Docker Desktop (for container builds)
   brew install --cask docker
   
   # Terraform (optional, for Terraform deployment)
   brew install terraform
   ```

**For detailed setup instructions, see**: [OPENSHIFT_LOCAL_SETUP.md](OPENSHIFT_LOCAL_SETUP.md)

### Project Dependencies

The solution requires the following local packages to be available:
- `experiment_bofa` (from `Experiment-Broker-Module/experiment_code/experiment_bofa`)
- `experiment_runner_lite` (from `chaos-toolkit-lite/experiment_runner_lite`)
- `experiment_broker_logging` (from `Experiment-Broker-Logging-Module`)

## Quick Start

### Container Engine Options

This deployment supports both Docker and Podman:

- **Docker**: Use the scripts in `scripts/` directory (see below)
- **Podman**: See the [Podman Guide](podman/README.md) for Podman-specific instructions

### 1. Build Container Images

**Using Docker (default):**

```bash
cd terraform/openshift_deployment

# Build images (defaults to local registry)
./scripts/build-images.sh

# Or specify custom registry and tag
REGISTRY=my-registry.com IMAGE_TAG=v1.0.0 ./scripts/build-images.sh
```

**Using Podman:**

See [podman/README.md](podman/README.md) for Podman-specific build and run instructions.

### 2. Import Images to OpenShift

If using CRC or local OpenShift:

```bash
# Import handler image
oc import-image chaos-broker-handler:latest \
  --from=chaos-broker-handler:latest \
  --confirm \
  -n chaos-broker

# Import orchestrator image
oc import-image chaos-broker-orchestrator:latest \
  --from=chaos-broker-orchestrator:latest \
  --confirm \
  -n chaos-broker
```

Or if you have a container registry:

```bash
# Tag and push to registry
docker tag chaos-broker-handler:latest <registry>/chaos-broker-handler:latest
docker push <registry>/chaos-broker-handler:latest

docker tag chaos-broker-orchestrator:latest <registry>/chaos-broker-orchestrator:latest
docker push <registry>/chaos-broker-orchestrator:latest
```

### 3. Deploy Using Terraform

```bash
cd terraform/openshift_deployment/terraform

# Copy and customize terraform.tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your OpenShift context
# Then initialize and apply
terraform init
terraform plan
terraform apply
```

### 4. Deploy Using kubectl/oc (Alternative)

```bash
cd terraform/openshift_deployment

# Deploy all manifests
./scripts/deploy.sh

# Or manually apply manifests
oc apply -f manifests/
```

## Directory Structure

```
terraform/openshift_deployment/
├── docker/
│   ├── Dockerfile                    # Handler service container
│   └── Dockerfile.orchestrator       # Orchestrator service container
├── podman/
│   ├── README.md                     # Podman-specific guide
│   ├── sample-payload.json           # Example payload for Podman
│   └── scripts/
│       ├── build-images.sh           # Build images with Podman
│       ├── run-handler.sh            # Run handler container
│       ├── run-orchestrator.sh       # Run orchestrator container
│       └── cleanup.sh                # Clean up containers/images
├── orchestrator/
│   ├── handler_service.py            # HTTP wrapper for handler.py
│   └── orchestrator.py               # Step Functions replacement
├── manifests/
│   ├── namespace.yaml                # Namespace creation
│   ├── configmap.yaml                # Configuration
│   ├── persistent-volume-claim.yaml  # Storage for experiments/journals
│   ├── deployment-handler.yaml       # Handler service deployment
│   ├── deployment-orchestrator.yaml  # Orchestrator deployment
│   ├── service-handler.yaml          # Handler service
│   ├── service-orchestrator.yaml     # Orchestrator service
│   └── route-handler.yaml            # OpenShift route (external access)
├── terraform/
│   ├── provider.tf                   # Terraform provider configuration
│   ├── variables.tf                  # Variable definitions
│   ├── main.tf                       # Main Terraform resources
│   ├── outputs.tf                    # Output values
│   └── terraform.tfvars.example      # Example configuration
├── scripts/
│   ├── build-images.sh               # Build container images (Docker)
│   └── deploy.sh                     # Deployment script
├── sample-payload.json               # Example orchestrator payload
└── README.md                         # This file
```

## Usage

### Workflow: Payload → Orchestrator → Handler → Persistent Volume

The complete workflow is:
1. **Store experiment YAML files** in the persistent volume
2. **Send payload** to orchestrator service
3. **Orchestrator invokes handler** for each experiment
4. **Handler reads experiment** from persistent volume and executes
5. **Results saved** to persistent volume journals directory

### Step 1: Upload Experiment Files to Persistent Volume

```bash
# Upload experiment file(s) to the handler pod's persistent volume
./scripts/upload-experiment.sh /path/to/experiment.yaml

# Or manually copy to pod
POD_NAME=$(oc get pods -n chaos-broker -l component=handler -o jsonpath='{.items[0].metadata.name}')
oc cp experiment.yaml chaos-broker/$POD_NAME:/app/local_only/experiments/experiment.yaml
```

### Step 2: Create Payload for Orchestrator

The payload references experiment files by name (relative to `/app/local_only/experiments/`):

```json
{
  "Payload": {
    "list": [
      {
        "local_mode": "openshift",
        "experiment_source": "experiment.yaml",
        "openshift_storage_path": "/app/local_only",
        "configuration": {
          "cluster_name": "my-cluster",
          "namespace": "default",
          "pod_label_selector": "app=nginx"
        }
      }
    ],
    "state": "pending"
  }
}
```

**Note**: `experiment_source` can be:
- Relative: `"experiment.yaml"` → resolves to `/app/local_only/experiments/experiment.yaml`
- Absolute: `"/app/local_only/experiments/experiment.yaml"` → used as-is

### Step 3: Send Payload to Orchestrator Service

```bash
# Port-forward orchestrator service
oc port-forward -n chaos-broker svc/chaos-broker-orchestrator 8081:8081

# In another terminal, send payload
curl -X POST http://localhost:8081/execute \
  -H "Content-Type: application/json" \
  -d @sample-payload.json
```

### Step 4: Handler Executes and Saves Results

The handler will:
- Read experiment from `/app/local_only/experiments/{experiment_source}`
- Execute the experiment
- Save journal to `/app/local_only/journals/experiment_*.json`

### Retrieve Results

```bash
# List journal files
oc exec -n chaos-broker deployment/chaos-broker-handler -- \
  ls -la /app/local_only/journals/

# Download a journal file
oc cp chaos-broker/$(oc get pods -n chaos-broker -l component=handler -o jsonpath='{.items[0].metadata.name}'):/app/local_only/journals/experiment_2025-11-25-14-58-00.json ./result.json
```

See [WORKFLOW.md](WORKFLOW.md) for detailed workflow documentation.

## Configuration

### Environment Variables

The handler service uses these environment variables (configured via ConfigMap):

- `PORT`: HTTP port (default: 8080)
- `local_mode`: Execution mode (set to "openshift" for OpenShift deployment)
- `execution_mode`: Set to "openshift"
- `execution_provider`: Set to "openshift"
- `skip_aws_services`: Set to "true"

### Storage

Experiments and journals are stored in:
- `/app/local_only/experiments/` - Experiment YAML files
- `/app/local_only/journals/` - Experiment execution journals

These directories are backed by a PersistentVolumeClaim.

### Setting Up Storage for CRC/Local OpenShift

CRC doesn't have dynamic storage provisioning by default. You have two options:

**Option 1: Create a test PersistentVolume (Recommended for CRC)**

```bash
# Create a test PV and PVC
./scripts/create-test-pv.sh

# This creates:
# - A PersistentVolume using hostPath
# - A PersistentVolumeClaim bound to it
# - Storage at /tmp/chaos-broker-storage (on your Mac)
```

**Option 2: Use emptyDir (No persistence, testing only)**

Modify the deployment to use `emptyDir` instead of PVC. This loses data on pod restart.

### Adding Experiment Files

1. **Via upload script** (recommended):
   ```bash
   ./scripts/upload-experiment.sh /path/to/experiment.yaml
   ```

2. **Via kubectl/oc copy**:
   ```bash
   POD_NAME=$(oc get pods -n chaos-broker -l component=handler -o jsonpath='{.items[0].metadata.name}')
   oc cp /path/to/experiment.yaml chaos-broker/$POD_NAME:/app/local_only/experiments/experiment.yaml
   ```

3. **Via ConfigMap** (for small files):
   ```bash
   oc create configmap experiments \
     --from-file=experiment.yaml=/path/to/experiment.yaml \
     -n chaos-broker
   ```

## Step Functions Logic Replication

The orchestrator (`orchestrator.py`) replicates the AWS Step Functions state machine:

1. **FirstChoiceState**: Checks payload state (pending/done)
2. **MapState**: Iterates through experiment list
3. **ProcessPayload**: Invokes handler service
4. **ChoiceState**: Checks result state
5. **IsPendingState**: Waits and retries if pending
6. **Retry/Catch**: Error handling with retries

### State Machine Flow

```
Start → FirstChoiceState → MapState (for each experiment)
  ↓
ProcessPayload → ChoiceState
  ↓
  ├─→ IsPendingState (wait 15s) → ProcessPayload (retry)
  └─→ Completed
```

## Troubleshooting

### Check Pod Status

```bash
oc get pods -n chaos-broker
oc describe pod <pod-name> -n chaos-broker
oc logs <pod-name> -n chaos-broker
```

### Check Services

```bash
oc get svc -n chaos-broker
oc describe svc chaos-broker-handler -n chaos-broker
```

### Check Storage

```bash
oc get pvc -n chaos-broker
oc describe pvc chaos-broker-storage -n chaos-broker
```

### Debug Handler Service

```bash
# Port-forward and test
oc port-forward -n chaos-broker svc/chaos-broker-handler 8080:8080

# In another terminal
curl http://localhost:8080/health
curl -X POST http://localhost:8080/invoke \
  -H "Content-Type: application/json" \
  -d @sample-payload.json
```

### View Logs

```bash
# Handler service logs
oc logs -f deployment/chaos-broker-handler -n chaos-broker

# Orchestrator logs
oc logs -f deployment/chaos-broker-orchestrator -n chaos-broker
```

### Common Issues

1. **Image Pull Errors**:
   - Ensure images are built and available
   - Check image pull policy (set to `IfNotPresent` for local images)

2. **Storage Issues**:
   - Verify PVC is bound: `oc get pvc -n chaos-broker`
   - Check storage class is available for your cluster

3. **Handler Service Not Responding**:
   - Check pod is running: `oc get pods -n chaos-broker`
   - Check service endpoints: `oc get endpoints chaos-broker-handler -n chaos-broker`
   - Verify health endpoint: `curl http://localhost:8080/health`

4. **Experiment Files Not Found**:
   - Verify files are in the PVC
   - Check mount path: `/app/local_only/experiments/`
   - Use absolute paths in experiment_source

## Local Development

### Running Handler Service Locally

```bash
cd Experiment-Broker-Module/experiment_code/lambda
source chaos-venv/bin/activate

# Set environment variables
export local_mode=openshift
export execution_mode=openshift

# Run handler service
python ../terraform/openshift_deployment/orchestrator/handler_service.py
```

### Running Orchestrator Locally

```bash
cd terraform/openshift_deployment/orchestrator

# Install dependencies
pip install requests

# Run orchestrator
python orchestrator.py \
  --payload-file ../sample-payload.json \
  --handler-url http://localhost:8080
```

## Differences from AWS Deployment

| AWS Component | OpenShift Replacement |
|---------------|----------------------|
| Lambda Function | Handler Service (HTTP) |
| Step Functions | Orchestrator Service (Python) |
| S3 Bucket | PersistentVolumeClaim |
| CloudWatch Logs | OpenShift/Kubernetes Logs |
| IAM Roles | ServiceAccount + RBAC |
| Secrets Manager | ConfigMap/Secrets |

## Next Steps

1. **Customize Configuration**: Edit `terraform/terraform.tfvars` or `manifests/configmap.yaml`
2. **Add Experiments**: Place experiment YAML files in the PVC
3. **Monitor Execution**: Use `oc logs` or OpenShift web console
4. **Scale Services**: Adjust replicas in deployment manifests
5. **Add Authentication**: Configure OpenShift OAuth or ServiceAccount tokens

## Support

For issues or questions:
- Check logs: `oc logs -f deployment/chaos-broker-handler -n chaos-broker`
- Review handler documentation: `Experiment-Broker-Module/experiment_code/lambda/README.md`
- Check OpenShift/Kubernetes resources: `oc get all -n chaos-broker`

