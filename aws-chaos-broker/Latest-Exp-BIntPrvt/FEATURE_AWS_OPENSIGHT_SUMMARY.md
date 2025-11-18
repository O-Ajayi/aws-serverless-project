# Feature Branch: feature/aws-openshift - Summary

## Overview

This feature branch adds AWS EKS (Elastic Kubernetes Service) cluster infrastructure with Terraform and enhances the handler function to support execution mode switching based on `local_mode` flag.

## Changes Made

### 1. ✅ Feature Branch Created
- Branch: `feature/aws-openshift`
- Created from: `feature/vr-prj`

### 2. ✅ Terraform EKS Infrastructure
**Location**: `terraform/eks_infra/`

Created complete Terraform configuration for:
- **VPC**: Custom VPC with public/private subnets across 2 AZs
- **Networking**: NAT gateways, internet gateway, route tables
- **EKS Cluster**: Managed Kubernetes cluster (v1.28)
- **Master Node**: Single master node (t3.medium)
- **Worker Nodes**: Auto-scaling worker node group (t3.large, 1-4 nodes)
- **IAM**: Roles and policies for EKS and node groups
- **Security**: Security groups and network ACLs

**Files Created**:
- `provider.tf` - AWS and Kubernetes providers
- `variables.tf` - Input variables
- `vpc.tf` - VPC and networking resources
- `eks.tf` - EKS cluster and node groups
- `iam.tf` - IAM roles and policies
- `outputs.tf` - Terraform outputs
- `versions.tf` - Terraform version requirements
- `terraform.tfvars.example` - Example configuration
- `.gitignore` - Git ignore rules
- `README.md` - Comprehensive documentation

### 3. ✅ Sample Pod Chaos Experiment
**Location**: `terraform/eks_infra/experiments/pod-chaos-termination.yml`

Created a sample experiment that:
- Tests pod resilience by terminating a pod
- Verifies pod exists and is ready (steady-state hypothesis)
- Terminates the pod (method)
- Waits for pod recreation and readiness (verification)

### 4. ✅ Handler Function Update
**Location**: `Experiment-Broker-Module/experiment_code/lambda/handler.py`
**Line**: 202-216

Added switch logic based on `local_mode` flag:
- **Local Mode** (`local_mode=true`):
  - Sets `execution_mode = "local"`
  - Sets `skip_aws_services = true`
  - Enables local testing without AWS dependencies

- **AWS Mode** (`local_mode=false`):
  - Sets `execution_mode = "aws"`
  - Sets `skip_aws_services = false`
  - Enables full AWS service integration

### 5. ✅ Comprehensive README
**Location**: `terraform/eks_infra/README.md`

Includes:
- Overview and architecture
- Prerequisites
- Step-by-step deployment instructions
- Infrastructure details
- Chaos experiment execution guide
- Handler configuration explanation
- Troubleshooting guide
- Cost estimation
- Security considerations

## Key Features

### EKS Cluster Architecture
- **1 Master Node**: t3.medium for cluster management
- **2 Worker Nodes**: t3.large (scalable 1-4) for workloads
- **High Availability**: Multi-AZ deployment
- **Security**: Private subnets for nodes, public subnets for load balancers

### Handler Execution Modes
- **Local Mode**: For development and testing
  - No AWS dependencies required
  - Faster iteration
  - Local file system for experiments

- **AWS Mode**: For production execution
  - Full AWS integration
  - S3 for experiment storage
  - CloudWatch logging
  - ECS metadata integration

## Usage Examples

### Deploy EKS Cluster
```bash
cd terraform/eks_infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform plan
terraform apply
```

### Configure kubectl
```bash
aws eks update-kubeconfig --region us-west-2 --name chaos-broker-eks
kubectl get nodes
```

### Run Experiment Locally
```bash
cd Experiment-Broker-Module/experiment_code/lambda
source chaos-venv/bin/activate
export local_mode=true
export experiment_source=../../../../terraform/eks_infra/experiments/pod-chaos-termination.yml
python handler.py
```

### Run Experiment via Lambda
```json
{
  "local_mode": false,
  "experiment_source": "experiments/pod-chaos-termination.yml",
  "bucket_name": "your-bucket",
  "output_bucket": "output-bucket",
  "output_path": "results/"
}
```

## Next Steps

1. **Review and Test**: Review the Terraform configuration and test deployment
2. **Customize**: Update variables in `terraform.tfvars` for your environment
3. **Deploy**: Deploy the EKS cluster using Terraform
4. **Configure**: Set up kubectl and verify cluster access
5. **Test Experiments**: Run the sample pod chaos experiment
6. **Integrate**: Integrate with your CI/CD pipeline

## Dependencies

### Terraform Modules
- `terraform-aws-modules/eks/aws` (~> 19.0)

### AWS Services
- EKS
- VPC
- EC2
- IAM
- CloudWatch

### Tools Required
- Terraform >= 1.0
- AWS CLI
- kubectl
- Python 3.9+ (for handler)

## Testing Checklist

- [ ] Terraform plan succeeds
- [ ] Terraform apply completes successfully
- [ ] kubectl can connect to cluster
- [ ] Nodes are in Ready state
- [ ] Handler works in local mode
- [ ] Handler works in AWS mode
- [ ] Sample experiment executes successfully
- [ ] Pod termination experiment works

## Notes

- The EKS cluster uses the AWS-managed Kubernetes control plane
- Worker nodes are in private subnets for security
- NAT gateways are used for outbound internet access
- IAM roles follow least privilege principle
- All resources are tagged for cost tracking

## Support

For issues or questions:
1. Check `terraform/eks_infra/README.md`
2. Review Terraform documentation
3. Check AWS EKS documentation
4. Review experiment logs

---

**Branch**: `feature/aws-openshift`
**Created**: 2024-11-04
**Status**: ✅ Complete

