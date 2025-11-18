# AWS EKS Cluster Infrastructure for Chaos Broker

This directory contains Terraform configuration for deploying an Amazon EKS (Elastic Kubernetes Service) cluster with one master node and multiple worker nodes for chaos testing experiments.

## Overview

The infrastructure includes:
- **VPC**: Custom VPC with public and private subnets across 2 availability zones
- **EKS Cluster**: Managed Kubernetes cluster with version 1.28
- **Master Node**: Single master node (t3.medium) for cluster management
- **Worker Nodes**: Auto-scaling worker node group (t3.large) with 1-4 nodes
- **Networking**: NAT gateways, internet gateway, and route tables configured
- **Security**: IAM roles and policies for EKS and node groups

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **AWS CLI** installed and configured
   ```bash
   aws --version
   aws configure
   ```

2. **Terraform** (>= 1.0) installed
   ```bash
   terraform version
   ```

3. **kubectl** installed
   ```bash
   kubectl version --client
   ```

4. **AWS Permissions**: Your AWS credentials must have permissions to:
   - Create VPCs, subnets, and networking resources
   - Create EKS clusters and node groups
   - Create IAM roles and policies
   - Manage EC2 instances

5. **S3 Backend** (optional but recommended): Configure an S3 bucket for Terraform state storage

## Quick Start

### Step 1: Configure Variables

Copy the example variables file and customize it:

```bash
cd terraform/eks_infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your desired values:

```hcl
aws_region = "us-west-2"
environment = "dev"
cluster_name = "chaos-broker-eks"
cluster_version = "1.28"

# Master Node Configuration
master_node_instance_type = "t3.medium"

# Worker Node Configuration
worker_node_instance_type = "t3.large"
worker_node_min_size = 1
worker_node_max_size = 4
worker_node_desired_size = 2
```

### Step 2: Initialize Terraform

```bash
terraform init
```

This will:
- Download required providers (AWS, Kubernetes)
- Initialize the backend (if configured)

### Step 3: Review the Plan

```bash
terraform plan
```

Review the resources that will be created. You should see:
- VPC and networking resources
- EKS cluster
- Master node group (1 node)
- Worker node group (2 nodes)
- IAM roles and policies

### Step 4: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. This will take approximately 15-20 minutes to complete.

### Step 5: Configure kubectl

After deployment completes, configure kubectl to use your new cluster:

```bash
# Get the command from Terraform output
terraform output kubectl_config_command

# Or manually run:
aws eks update-kubeconfig --region us-west-2 --name chaos-broker-eks
```

Verify the connection:

```bash
kubectl get nodes
```

You should see:
- 1 master node
- 2 worker nodes (or your desired_size)

### Step 6: Verify Cluster Status

```bash
# Check cluster status
kubectl cluster-info

# List all nodes
kubectl get nodes -o wide

# Check node labels
kubectl get nodes --show-labels
```

## Infrastructure Details

### Network Architecture

```
VPC (10.0.0.0/16)
├── Public Subnet 1 (10.0.0.0/24) - AZ 1
│   ├── NAT Gateway 1
│   └── Internet Gateway
├── Public Subnet 2 (10.0.1.0/24) - AZ 2
│   ├── NAT Gateway 2
│   └── Internet Gateway
├── Private Subnet 1 (10.0.2.0/24) - AZ 1
│   └── EKS Nodes
└── Private Subnet 2 (10.0.3.0/24) - AZ 2
    └── EKS Nodes
```

### Node Groups

1. **Master Node Group**:
   - Instance type: t3.medium (configurable)
   - Count: 1 (fixed)
   - Purpose: Cluster management and control plane

2. **Worker Node Group**:
   - Instance type: t3.large (configurable)
   - Min size: 1
   - Max size: 4
   - Desired size: 2 (configurable)
   - Purpose: Running application workloads and chaos experiments

### EKS Addons

The cluster includes these managed addons:
- **CoreDNS**: DNS and service discovery
- **kube-proxy**: Network proxy for services
- **VPC CNI**: Networking for pods
- **AWS EBS CSI Driver**: Persistent volume support

## Running Chaos Experiments

### Step 1: Prepare Your Experiment

Copy the sample experiment from `experiments/pod-chaos-termination.yml` and customize it:

```bash
cp experiments/pod-chaos-termination.yml my-experiment.yml
```

### Step 2: Configure Experiment

Update the experiment YAML with your specific values:

```yaml
configuration:
  aws_region: us-west-2
  cluster_name: chaos-broker-eks
  namespace: default
  pod_label_selector: "app=nginx"
```

### Step 3: Run Experiment Locally

Using the lambda handler with local mode:

```bash
cd Experiment-Broker-Module/experiment_code/lambda
source chaos-venv/bin/activate

export local_mode=true
export experiment_source=../../../../terraform/eks_infra/experiments/pod-chaos-termination.yml
export bucket_name=dummy
export output_bucket=dummy
export output_path=dummy

python handler.py
```

### Step 4: Run Experiment via Lambda

Deploy the handler to AWS Lambda and invoke it with:

```json
{
  "local_mode": false,
  "experiment_source": "experiments/pod-chaos-termination.yml",
  "bucket_name": "your-experiment-bucket",
  "output_bucket": "your-output-bucket",
  "output_path": "results/",
  "configuration": {
    "aws_region": "us-west-2",
    "cluster_name": "chaos-broker-eks"
  }
}
```

## Handler Configuration

The handler function supports two execution modes:

### Local Mode (`local_mode: true`)

When `local_mode` is enabled:
- `execution_mode` is set to `"local"`
- `skip_aws_services` is set to `true`
- Experiments load from local filesystem
- AWS service interactions (S3, DynamoDB, OpenSearch) are skipped
- ECS metadata retrieval is skipped

### AWS Mode (`local_mode: false`)

When `local_mode` is disabled:
- `execution_mode` is set to `"aws"`
- `skip_aws_services` is set to `false`
- Experiments load from S3
- Full AWS service integration enabled
- ECS metadata and CloudWatch logging enabled

The handler automatically sets these flags based on the `local_mode` environment variable in the `__main__` block (line 206-216).

## Sample Experiment: Pod Chaos Termination

The included `pod-chaos-termination.yml` experiment:

1. **Steady State Hypothesis**: Verifies pod exists and is ready
2. **Method**: Terminates the pod
3. **Verification**: Waits for pod recreation and readiness

### Example Usage

```yaml
version: 1.0.0
title: Pod Termination Chaos Experiment
configuration:
  aws_region: us-west-2
  cluster_name: chaos-broker-eks
  namespace: default
  pod_label_selector: "app=nginx"
```

## Troubleshooting

### Issue: Terraform fails with "provider not found"

**Solution**: Run `terraform init` to download providers

### Issue: kubectl cannot connect to cluster

**Solution**: 
```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

### Issue: Nodes not joining cluster

**Solution**: 
1. Check IAM roles are attached correctly
2. Verify security groups allow traffic
3. Check CloudWatch logs for node group issues

### Issue: Handler fails with "local_mode not found"

**Solution**: Ensure `local_mode` environment variable is set:
```bash
export local_mode=true  # for local testing
# or
export local_mode=false  # for AWS execution
```

### Issue: Experiment fails to find pods

**Solution**:
1. Verify pod exists: `kubectl get pods -n <namespace>`
2. Check label selector matches: `kubectl get pods -l <label-selector>`
3. Verify RBAC permissions for service account

## Cost Estimation

Approximate monthly costs (us-west-2):

- **EKS Cluster**: ~$0.10/hour = ~$73/month
- **Master Node (t3.medium)**: ~$0.0416/hour = ~$30/month
- **Worker Nodes (2x t3.large)**: ~$0.0832/hour/node = ~$120/month
- **NAT Gateways (2x)**: ~$0.045/hour = ~$65/month
- **Data Transfer**: Variable

**Total**: ~$288/month base cost + data transfer

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will delete all resources including the EKS cluster and all data.

## Security Considerations

1. **Private Subnets**: Worker nodes are in private subnets for security
2. **IAM Roles**: Least privilege IAM roles for EKS and nodes
3. **Security Groups**: Restricted access to cluster endpoint
4. **Encryption**: Enable encryption at rest for EKS cluster (add to configuration)

## Deploy Sample Application

After the cluster is ready, deploy the sample nginx application:

```bash
# Navigate to kubernetes manifests
cd kubernetes_manifests

# Deploy nginx with 3 replicas
kubectl apply -f nginx-deployment.yaml

# Verify deployment
kubectl get pods -l app=nginx
kubectl get svc nginx-service-loadbalancer

# Get external IP (may take a few minutes)
kubectl get svc nginx-service-loadbalancer -w
```

See `kubernetes_manifests/README.md` for detailed instructions.

## Next Steps

1. **Deploy Sample Application**: Deploy nginx using the provided manifests (see above)
2. **Enable Cluster Autoscaler**: For automatic node scaling
3. **Set up Monitoring**: CloudWatch, Prometheus, or Grafana
4. **Configure RBAC**: Set up proper Kubernetes RBAC policies
5. **Run Chaos Experiments**: Test pod resilience with the sample experiment
6. **Set up CI/CD**: Integrate with your CI/CD pipeline

## Support

For issues or questions:
1. Check the main project README
2. Review Terraform documentation
3. Check AWS EKS documentation
4. Review experiment logs in CloudWatch

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

