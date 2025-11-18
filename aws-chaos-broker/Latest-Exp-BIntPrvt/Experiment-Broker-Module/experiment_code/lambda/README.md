# Lambda Handler - Setup and Testing Guide

This directory contains the AWS Lambda handler for running experiments, with support for local testing mode.

## Prerequisites

- Python 3.9 or higher
- pip and setuptools

## Setup Instructions

### Quick Setup (Recommended)

Use the provided `setup.sh` script for automated setup:

```bash
# Make sure the script is executable
chmod +x setup.sh

# Run the setup script
./setup.sh
```

The script will:
1. Create a virtual environment (if it doesn't exist)
2. Install dependencies from `requirements.txt`
3. Install local packages (`experiment_bofa`, `experiment_runner_lite`, `experiment_broker_logging`)
4. Verify the installation

### Manual Setup

#### 1. Create and Activate Virtual Environment

```bash
# From the lambda directory
python3 -m venv chaos-venv

# Activate virtual environment
# On macOS/Linux:
source chaos-venv/bin/activate

# On Windows:
chaos-venv\Scripts\activate
```

#### 2. Install Dependencies

```bash
# Install all required packages
pip install -r requirements.txt
```

#### 3. Install Local Packages

The handler depends on three local packages. You need to install them in development mode:

**run from experiment_root:**
```bash
cd ./Experiment-Broker-Module/experiment_code/experiment_bofa
pip install -e . --no-build-isolation

cd ../../../experiment_runner_lite/
pip install -e . --no-build-isolation

cd ../Experiment-Broker-Logging-Module/
pip install -e . --no-build-isolation
```

**experiment_bofa:**
```bash
# From the project root
cd ../../Experiment-Broker-Module/experiment_code/experiment_bofa
pip install -e . --no-build-isolation
```

**experiment_runner_lite:**
```bash
# From the project root
cd ../../experiment_runner_lite
pip install -e . --no-build-isolation
```

**experiment_broker_logging:**
```bash
# From the project root
cd ../../Experiment-Broker-Logging-Module
pip install -e . --no-build-isolation
```

#### 4. Verify Installation

```bash
python -c "import handler; print('✓ handler imported successfully')"
python -c "import experiment_bofa; print('✓ experiment_bofa imported successfully')"
python -c "import experiment_runner_lite; print('✓ experiment_runner_lite imported successfully')"
python -c "import experiment_broker_logging; print('✓ experiment_broker_logging imported successfully')"
python -c "import boto3; print('✓ boto3 imported successfully')"
```

## Running Tests

Once all dependencies are installed, you can run the tests:

### Recommended: Use the test runner script

```bash
# Run all tests (automatically activates venv)
./run_tests.sh

# Run with verbose output
./run_tests.sh -v

# Run a specific test
./run_tests.sh TestHandlerLocalMode.test_local_mode_loads_from_file_system
```

### Manual: Activate virtual environment first

```bash
# IMPORTANT: Activate the virtual environment first!
source chaos-venv/bin/activate

# Then run tests
python -m unittest test_handler_local_mode -v

# Run a specific test
python -m unittest test_handler_local_mode.TestHandlerLocalMode.test_local_mode_loads_from_file_system
```

**Note:** Make sure the virtual environment is activated before running tests, otherwise you'll get `ModuleNotFoundError` for the local packages.

## Running the Handler in Different Modes

The handler supports two execution paths:

| Mode        | `local_mode` | Provider        | Experiment Source         | AWS Services |
|-------------|--------------|-----------------|---------------------------|--------------|
| AWS         | `false`      | `aws`           | S3 object (`bucket/key`)  | Enabled      |
| Local/On-Prem (OpenShift) | `true`       | `openshift` (default) | Local file path            | Skipped      |

### AWS Mode (`local_mode = false`)

1. **Upload your experiment to S3**
   ```bash
   aws s3 cp ../../../terraform/eks_infra/experiments/pod-chaos-termination.yml \
       s3://experiment-bucket-111222333/experiments/pod-chaos-termination.yml
   ```

2. **Update `terraform/test_payload_aws.json`** if needed, then invoke either via the Lambda console or:
   ```bash
   aws lambda invoke \
     --function-name chaos-broker-handler \
     --payload file://terraform/test_payload_aws.json \
     response.json
   cat response.json | jq .
   ```

3. **Expected event (excerpt)**:
   ```json
   {
     "local_mode": false,
     "bucket_name": "experiment-bucket-111222333",
     "experiment_source": "experiments/pod-chaos-termination.yml",
     "output_bucket": "experiment-bucket-111222333",
     "output_path": "results/"
   }
   ```

### Local / OpenShift Mode (`local_mode = true`)

1. **Deploy sample workload (optional)**
   ```bash
   cd ../../../terraform/eks_infra/kubernetes_manifests
   kubectl apply -f nginx-deployment.yaml
   ```

2. **Set environment variables and run the handler**
   ```bash
   cd ../../Experiment-Broker-Module/experiment_code/lambda
   source chaos-venv/bin/activate

   export local_mode=true
   export experiment_source=$(pwd)/../../../terraform/eks_infra/experiments/pod-chaos-termination.yml
   export execution_provider=openshift
   export openshift_cluster_name=ocp-dev
   export openshift_namespace=chaos-testing

   python handler.py
   ```

3. **Expected event (excerpt)**:
   ```json
   {
     "local_mode": true,
     "execution_provider": "openshift",
     "experiment_source": "/absolute/path/pod-chaos-termination.yml",
     "on_prem_target": {
       "provider": "openshift",
       "cluster_name": "ocp-dev",
       "namespace": "chaos-testing"
     }
   }
   ```

See [`LOCAL_MODE_TESTING_GUIDE.md`](LOCAL_MODE_TESTING_GUIDE.md) and
[`openshift_local/README.md`](openshift_local/README.md) for detailed steps,
including environment variables and cluster setup.

## Running Locally

You can also run the handler locally using `dev_exec.py`:

```bash
python dev_exec.py
```

Make sure to update the `experiment_source` path in `dev_exec.py` to point to a valid experiment YAML file on your system.

## Troubleshooting

### ImportError: No module named 'boto3'

Make sure you've activated your virtual environment and installed requirements:
```bash
source chaos-venv/bin/activate
pip install -r requirements.txt
```

### ModuleNotFoundError: No module named 'experiment_bofa'

The local `experiment_bofa` package needs to be installed:
```bash
# From the project root
cd ../../Experiment-Broker-Module/experiment_code/experiment_bofa
pip install -e . --no-build-isolation
```

### ModuleNotFoundError: No module named 'experiment_runner_lite'

The local `experiment_runner_lite` package needs to be installed:
```bash
# From the project root
cd ../../experiment_runner_lite
pip install -e . --no-build-isolation
```

### ModuleNotFoundError: No module named 'experiment_broker_logging'

The local `experiment_broker_logging` package needs to be installed:
```bash
# From the project root
cd ../../Experiment-Broker-Logging-Module
pip install -e . --no-build-isolation
```

### ImportError: Failed to import test module

This usually means:
1. Dependencies are not installed - run `pip install -r requirements.txt`
2. Local packages are not installed - run `./setup.sh` or install them manually as shown above
3. Virtual environment is not activated - make sure to activate it first

### pip install -e . fails with "No module named pip"

This means your virtual environment is broken. Recreate it:
```bash
deactivate  # if activated
rm -rf chaos-venv
python3 -m venv chaos-venv
source chaos-venv/bin/activate
pip install --upgrade pip setuptools wheel
```

## Requirements Overview

The `requirements.txt` includes:
- **boto3** - AWS SDK for Python
- **requests** - HTTP library for API calls
- **pytest** and related packages - For testing

## Terraform Deployments

- **AWS Lambda + S3**: `terraform/` (deploys the handler, IAM role, S3 bucket, etc.)
- **EKS Cluster**: `../../../terraform/eks_infra/`
- **Local OpenShift guidance**: `openshift_local/`

Each directory includes its own `README.md` with step-by-step instructions.

## Local Packages

The handler depends on three local packages that must be installed separately:
- **experiment_bofa** - S3 and AWS utilities (from `experiment_code/experiment_bofa`)
- **experiment_runner_lite** - Experiment runner framework (from `experiment_runner_lite`)
- **experiment_broker_logging** - Logging utilities (from `Experiment-Broker-Logging-Module`)

These packages are not on PyPI and must be installed in development mode using `pip install -e .` from their respective directories.

## Notes

- The local packages must be installed in development mode (`-e` flag) so code changes are reflected immediately
- Tests use mocking, so no actual AWS credentials or services are needed
- The `setup.sh` script handles all installation steps automatically
