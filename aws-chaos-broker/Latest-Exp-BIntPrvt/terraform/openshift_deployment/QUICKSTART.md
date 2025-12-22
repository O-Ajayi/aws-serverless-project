# Quick Start Guide - OpenShift Deployment

## Prerequisites Check

### First Time Setup

If you haven't set up OpenShift locally yet:

```bash
# Option 1: Automated setup (recommended)
cd terraform/openshift_deployment
./scripts/setup-crc.sh

# Option 2: Manual setup
# See OPENSHIFT_LOCAL_SETUP.md for detailed instructions
```

### Verify Environment

```bash
# Verify OpenShift/Kubernetes is running
oc cluster-info

# Verify you're logged in
oc whoami

# Verify Docker is running
docker ps

# Check CRC status (if using CRC)
crc status
```

## Step 1: Build Container Images

```bash
cd terraform/openshift_deployment
./scripts/build-images.sh
```

This builds:
- `chaos-broker-handler:latest` - Handler service container
- `chaos-broker-orchestrator:latest` - Orchestrator container

## Step 2: Import Images to OpenShift

```bash
# Create namespace first
oc create namespace chaos-broker

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

## Step 3: Deploy to OpenShift

### Option A: Using kubectl/oc (Fastest)

```bash
cd terraform/openshift_deployment
./scripts/deploy.sh
```

### Option B: Using Terraform

```bash
cd terraform/openshift_deployment/terraform

# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# Deploy
terraform init
terraform apply
```

## Step 4: Verify Deployment

```bash
# Check pods are running
oc get pods -n chaos-broker

# Check services
oc get svc -n chaos-broker

# Check route (OpenShift only)
oc get route -n chaos-broker
```

## Step 5: Test the Handler Service

```bash
# Port-forward to access service
oc port-forward -n chaos-broker svc/chaos-broker-handler 8080:8080

# In another terminal, test health endpoint
curl http://localhost:8080/health

# Test handler invocation
curl -X POST http://localhost:8080/invoke \
  -H "Content-Type: application/json" \
  -d '{
    "local_mode": "openshift",
    "experiment_source": "/app/local_only/experiments/experiment.yaml",
    "configuration": {
      "cluster_name": "my-cluster",
      "namespace": "default",
      "pod_label_selector": "app=nginx"
    }
  }'
```

## Step 6: Add Experiment Files

```bash
# Copy experiment file to a running pod
oc cp path/to/experiment.yaml \
  $(oc get pods -n chaos-broker -l component=handler -o jsonpath='{.items[0].metadata.name}'):/app/local_only/experiments/ \
  -n chaos-broker
```

## Step 7: Run Orchestrator

```bash
# Create a payload file
cat > payload.json <<EOF
{
  "Payload": {
    "list": [
      {
        "local_mode": "openshift",
        "experiment_source": "/app/local_only/experiments/experiment.yaml",
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
EOF

# Run orchestrator as a job
oc create job --from=deployment/chaos-broker-orchestrator test-orchestrator -n chaos-broker

# Or run locally with handler service URL
python orchestrator/orchestrator.py \
  --payload-file payload.json \
  --handler-url http://chaos-broker-handler.chaos-broker.svc.cluster.local:8080
```

## View Logs

```bash
# Handler service logs
oc logs -f deployment/chaos-broker-handler -n chaos-broker

# Orchestrator logs
oc logs -f deployment/chaos-broker-orchestrator -n chaos-broker
```

## Clean Up

```bash
# Delete all resources
oc delete namespace chaos-broker

# Or using Terraform
cd terraform/openshift_deployment/terraform
terraform destroy
```

## Troubleshooting

See the main [README.md](README.md) for detailed troubleshooting steps.

