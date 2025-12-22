# Deployment Summary - OpenShift Containerized Solution

## Overview

This solution containerizes the chaos-broker handler module and Step Functions orchestrator for deployment on OpenShift running locally on your MacBook.

## What's Included

### 1. Container Images
- **Handler Service**: HTTP REST API wrapper for `handler.py`
- **Orchestrator Service**: Python-based workflow orchestrator (Step Functions replacement)

### 2. OpenShift/Kubernetes Resources
- Namespace: `chaos-broker`
- ConfigMap: Configuration for services
- PersistentVolumeClaim: Storage for experiments and journals
- Deployments: Handler and orchestrator services
- Services: ClusterIP services for internal communication
- Route: External access (OpenShift only)

### 3. Terraform Infrastructure
- Complete Terraform configuration for OpenShift deployment
- Variable definitions and outputs
- Provider configuration for Kubernetes/OpenShift

### 4. Deployment Scripts
- `build-images.sh`: Build container images
- `deploy.sh`: Deploy using kubectl/oc or Terraform
- `Makefile`: Convenient shortcuts for common tasks

## Key Features

✅ **Step Functions Replacement**: Python orchestrator implements the same state machine logic  
✅ **Lambda Replacement**: HTTP service wrapper maintains handler compatibility  
✅ **Local Storage**: PersistentVolumeClaim replaces S3 for experiments/journals  
✅ **OpenShift Mode**: Handler configured for `local_mode="openshift"`  
✅ **Scalable**: Multiple replicas with resource limits  
✅ **Health Checks**: Liveness and readiness probes  
✅ **Complete Documentation**: README, QUICKSTART, and ARCHITECTURE docs  

## File Structure

```
terraform/openshift_deployment/
├── docker/
│   ├── Dockerfile                    # Handler service image
│   ├── Dockerfile.orchestrator       # Orchestrator image
│   └── .dockerignore                 # Docker ignore patterns
├── orchestrator/
│   ├── handler_service.py            # HTTP wrapper for handler.py
│   ├── orchestrator.py               # Step Functions replacement
│   └── requirements.txt              # Python dependencies
├── manifests/
│   ├── namespace.yaml                # Namespace
│   ├── configmap.yaml                # Configuration
│   ├── persistent-volume-claim.yaml  # Storage
│   ├── deployment-handler.yaml       # Handler deployment
│   ├── deployment-orchestrator.yaml  # Orchestrator deployment
│   ├── service-handler.yaml          # Handler service
│   ├── service-orchestrator.yaml     # Orchestrator service
│   └── route-handler.yaml            # OpenShift route
├── terraform/
│   ├── provider.tf                   # Terraform provider
│   ├── variables.tf                  # Variables
│   ├── main.tf                       # Main resources
│   ├── outputs.tf                    # Outputs
│   └── terraform.tfvars.example      # Example config
├── scripts/
│   ├── build-images.sh               # Build script
│   └── deploy.sh                     # Deploy script
├── sample-payload.json               # Example orchestrator payload
├── README.md                         # Full documentation
├── QUICKSTART.md                     # Quick start guide
├── ARCHITECTURE.md                   # Architecture details
└── Makefile                          # Convenience commands
```

## Quick Start

```bash
# 1. Build images
cd terraform/openshift_deployment
make build

# 2. Import images to OpenShift
oc import-image chaos-broker-handler:latest --from=chaos-broker-handler:latest --confirm -n chaos-broker
oc import-image chaos-broker-orchestrator:latest --from=chaos-broker-orchestrator:latest --confirm -n chaos-broker

# 3. Deploy
make deploy

# 4. Test
make test
```

## Next Steps

1. **Customize Configuration**: Edit `terraform/terraform.tfvars` or `manifests/configmap.yaml`
2. **Add Experiments**: Copy experiment YAML files to the PVC
3. **Run Orchestrator**: Use sample payload or create your own
4. **Monitor**: Check logs and pod status

See [README.md](README.md) for detailed instructions.

