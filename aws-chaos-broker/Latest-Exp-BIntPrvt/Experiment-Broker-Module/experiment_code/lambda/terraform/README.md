# Lambda Function Deployment - Terraform

This directory contains Terraform configuration for deploying the chaos broker handler as an AWS Lambda function with all necessary dependencies and an S3 bucket for storing experiment files.

## Overview

The Terraform configuration creates:
- **Lambda Function**: Deploys `handler.py` with all dependencies
- **S3 Bucket**: `experiment-bucket-111222333` for storing experiment files
- **IAM Roles**: Proper permissions for Lambda to access S3, Secrets Manager, EKS, etc.
- **CloudWatch Logs**: Log group for Lambda function logs
- **Lambda Function URL**: Optional HTTP endpoint for function invocation

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** (>= 1.0) installed
3. **Python 3.9+** for building the Lambda package
4. **pip** for installing dependencies

## Quick Start

### Step 1: Configure Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### Step 2: Initialize Terraform

```bash
terraform init
```

### Step 3: Review the Plan

```bash
terraform plan
```

### Step 4: Deploy

```bash
terraform apply
```

Type `yes` when prompted. This will:
1. Build the Lambda package with all dependencies
2. Create the S3 bucket
3. Create IAM roles and policies
4. Deploy the Lambda function
5. Create CloudWatch log group

### Step 5: Verify Deployment

```bash
# Check Lambda function
aws lambda get-function --function-name chaos-broker-handler

# Check S3 bucket
aws s3 ls s3://experiment-bucket-111222333

# Check logs
aws logs tail /aws/lambda/chaos-broker-handler --follow
```

## Testing Local Mode

### Option 1: Test Locally Without Lambda

#### Prerequisites

1. Set up the local environment:
```bash
cd ..  # Go back to lambda directory
source chaos-venv/bin/activate  # Activate virtual environment
```

2. Ensure all packages are installed:
```bash
./setup.sh
```

#### Test Handler in Local Mode

```bash
# Set local_mode environment variable
export local_mode=true

# Set experiment source (local file)
export experiment_source=../../../terraform/eks_infra/experiments/pod-chaos-termination.yml

# Set dummy values for other required variables
export bucket_name=dummy
export output_bucket=dummy
export output_path=dummy
export secret_arn=dummy

# Run handler directly
python handler.py
```

Or create a test script:

```bash
# Create test_local.sh
cat > test_local.sh << 'EOF'
#!/bin/bash
export local_mode=true
export experiment_source=../../../terraform/eks_infra/experiments/pod-chaos-termination.yml
export bucket_name=dummy
export output_bucket=dummy
export output_path=dummy
export secret_arn=dummy

python handler.py
EOF

chmod +x test_local.sh
./test_local.sh
```

### Option 2: Test Handler Function Directly

```bash
# Create a test event
cat > test_event.json << 'EOF'
{
  "local_mode": true,
  "experiment_source": "../../../terraform/eks_infra/experiments/pod-chaos-termination.yml",
  "configuration": {
    "aws_region": "us-east-1"
  }
}
EOF

# Run handler with test event
python -c "
import json
from handler import handler

with open('test_event.json', 'r') as f:
    event = json.load(f)

class MockContext:
    function_name = 'test'
    aws_request_id = 'test-request-id'

result = handler(event, MockContext())
print(json.dumps(result, indent=2))
"
```

### Option 3: Test with dev_exec.py

```bash
# Edit dev_exec.py to set local_mode
# Then run:
python dev_exec.py
```

## Testing Lambda Function (Deployed)

### Invoke Lambda Function Directly

```bash
# Invoke with local_mode=true
aws lambda invoke \
  --function-name chaos-broker-handler \
  --payload '{
    "local_mode": true,
    "experiment_source": "experiments/test.yml",
    "bucket_name": "experiment-bucket-111222333",
    "output_bucket": "experiment-bucket-111222333",
    "output_path": "results/"
  }' \
  response.json

cat response.json | jq .
```

### Step 6: Choose the Experiment Source

| Mode / Target        | `local_mode` | Experiment Source                                               | Steps                                                                                          |
|----------------------|--------------|-----------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| AWS Lambda           | `false`      | S3 object (`s3://experiment-bucket-111222333/experiments/...`)  | Upload the YAML: `aws s3 cp <file> s3://experiment-bucket-111222333/experiments/<file>.yml`     |
| Local / OpenShift    | `true`       | Local filesystem path (`/path/to/experiment.yml`)               | Provide a valid path when invoking locally; no upload required                                 |

Sample payload templates are available in `Experiment-Broker-Module/experiment_code/lambda/`:

- `payload_aws.json`
- `payload_local_openshift.json`

Use them as a starting point and adjust values before invoking via console or CLI.

### Invoke via Function URL (if enabled)

```bash
# Get the function URL
FUNCTION_URL=$(terraform output -raw lambda_function_url)

# Invoke via HTTP
curl -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "local_mode": true,
    "experiment_source": "experiments/test.yml",
    "bucket_name": "experiment-bucket-111222333",
    "output_bucket": "experiment-bucket-111222333",
    "output_path": "results/"
  }'
```

### Upload Experiment to S3 and Test

```bash
# Upload experiment file to S3
aws s3 cp \
  ../../../terraform/eks_infra/experiments/pod-chaos-termination.yml \
  s3://experiment-bucket-111222333/experiments/pod-chaos-termination.yml

# Invoke Lambda with S3 experiment
aws lambda invoke \
  --function-name chaos-broker-handler \
  --payload '{
    "local_mode": false,
    "experiment_source": "experiments/pod-chaos-termination.yml",
    "bucket_name": "experiment-bucket-111222333",
    "output_bucket": "experiment-bucket-111222333",
    "output_path": "results/",
    "configuration": {
      "aws_region": "us-east-1",
      "cluster_name": "chaos"
    }
  }' \
  response.json

cat response.json | jq .
```

## Local Mode vs AWS Mode

### Local Mode (`local_mode: true`)

When testing locally:
- **execution_mode**: Set to `"local"`
- **skip_aws_services**: Set to `true`
- Experiments load from local filesystem
- No S3, DynamoDB, or OpenSearch interactions
- No ECS metadata retrieval
- Faster for development and testing

**Use Case**: Development, local testing, debugging

### AWS Mode (`local_mode: false`)

When deployed to Lambda:
- **execution_mode**: Set to `"aws"`
- **skip_aws_services**: Set to `false`
- Experiments load from S3
- Full AWS service integration
- ECS metadata and CloudWatch logging enabled
- Production-ready execution

**Use Case**: Production deployments, CI/CD pipelines

## Handler Execution Modes

The handler automatically detects the mode based on the `local_mode` flag:

```python
# In handler.py __main__ block (line 206-216)
local_mode = os.environ.get("local_mode", "false").lower() == "true"
if local_mode:
    event["execution_mode"] = "local"
    event["skip_aws_services"] = True
else:
    event["execution_mode"] = "aws"
    event["skip_aws_services"] = False
```

## Testing Workflow

### 1. Local Development

```bash
# Activate virtual environment
source chaos-venv/bin/activate

# Test locally with local_mode
export local_mode=true
python handler.py
```

### 2. Deploy to Lambda

```bash
cd terraform
terraform apply
```

### 3. Test Deployed Lambda

```bash
# Test with local_mode=false (AWS mode)
aws lambda invoke \
  --function-name chaos-broker-handler \
  --payload file://test_payload.json \
  response.json
```

### 4. Monitor Logs

```bash
# View logs in real-time
aws logs tail /aws/lambda/chaos-broker-handler --follow

# View specific log stream
aws logs get-log-events \
  --log-group-name /aws/lambda/chaos-broker-handler \
  --log-stream-name <stream-name>
```

## Troubleshooting

### Issue: Lambda package is too large

**Solution**: 
- Exclude unnecessary files from package
- Use Lambda layers for large dependencies
- Optimize dependencies

### Issue: Import errors in Lambda

**Solution**:
1. Check that all dependencies are in the package
2. Verify local packages (experiment_bofa, experiment_runner_lite) are included
3. Check CloudWatch logs for specific import errors

### Issue: local_mode not working

**Solution**:
1. Ensure `local_mode` is set as environment variable or in event
2. Check handler.py line 206-216 for switch logic
3. Verify the flag is being passed correctly

### Issue: S3 access denied

**Solution**:
1. Check IAM role permissions
2. Verify S3 bucket policy
3. Check bucket name matches configuration

### Issue: Handler timeout

**Solution**:
1. Increase timeout in `variables.tf`
2. Optimize experiment execution
3. Check CloudWatch logs for bottlenecks

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will delete:
- Lambda function
- S3 bucket and all contents
- IAM roles and policies
- CloudWatch log groups

## Monitoring

### CloudWatch Metrics

- Invocations
- Duration
- Errors
- Throttles

### CloudWatch Logs

```bash
# View logs
aws logs tail /aws/lambda/chaos-broker-handler --follow

# Search logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/chaos-broker-handler \
  --filter-pattern "ERROR"
```

## Cost Estimation

Approximate monthly costs (us-east-1):

- **Lambda**: 
  - Requests: $0.20 per 1M requests
  - Compute: $0.0000166667 per GB-second
  - Example: 100K requests/month, 512MB, 5s average = ~$0.42/month

- **S3**: 
  - Storage: $0.023 per GB
  - Requests: $0.0004 per 1K PUT requests
  - Example: 10GB storage, 10K requests = ~$0.27/month

- **CloudWatch Logs**: 
  - $0.50 per GB ingested
  - $0.03 per GB stored
  - Example: 1GB/month = ~$0.53/month

**Total**: ~$1.22/month (example usage)

## Security Considerations

1. **IAM Roles**: Least privilege principle
2. **S3 Encryption**: Server-side encryption enabled
3. **S3 Public Access**: Blocked
4. **Secrets**: Use AWS Secrets Manager for sensitive data
5. **VPC**: Consider VPC configuration for EKS access

## Next Steps

1. **Set up CI/CD**: Automate Lambda deployment
2. **Add Monitoring**: Set up CloudWatch alarms
3. **Configure VPC**: If Lambda needs VPC access
4. **Add Layers**: Use Lambda layers for common dependencies
5. **Optimize Package**: Reduce package size if needed

## References

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)

