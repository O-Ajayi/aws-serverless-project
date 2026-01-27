## Getting Started: Chaos Tool and Experiment Broker

This guide explains how to run the Experiment Broker and the Chaos Tool components in different environments, and how experiment files are structured and executed.

### Overview
- **Experiment Broker**: Orchestrates chaos experiments and delegates execution to the handler.
- **Chaos Tool (experiment_bofa / experimentvr)**: Implements actions and probes used by experiment files.
- **Experiment files**: YAML definitions that describe actions and probes to execute.

### Prerequisites
- Python 3.9+ (3.13 supported by CI)
- `pip`, `setuptools`, `wheel`
- AWS credentials for AWS mode
- OpenShift/CRC for OpenShift mode (optional)

### Repository Structure (Relevant Paths)
- `Experiment-Broker-Module/experiment_code/experiment_bofa/` (Chaos tool actions/probes)
- `Experiment-Broker-Module/experiment_code/lambda/` (Handler code and local test payloads)
- `terraform/openshift_deployment/` (OpenShift manifests, docker/podman builds)
- `src/` (CI build path; symlinked to `Experiment-Broker-Module/experiment_code`)

### Install Dependencies (Local Dev)
```bash
python -m venv venv
source venv/bin/activate
pip install -r src/requirements.txt
```

### Experiment File Basics
Experiment files describe:
- **title** and **description**
- **steady-state-hypothesis** (optional)
- **method** with actions and probes

Example (minimal):
```yaml
version: 1.0.0
title: Example Experiment
description: Smoke test example
method:
  - type: action
    name: example-action
    provider:
      type: python
      module: experiment_bofa.s3.actions
      func: list_buckets
```

### Running Modes

#### AWS Mode
- Experiment files stored in **S3**
- Execution via AWS Lambda and Step Functions
- Payloads like `payload_aws.json` in `Experiment-Broker-Module/experiment_code/lambda/`

#### Local-Only Mode
- Experiment files stored on **local filesystem**
- Handler reads from `local_only/experiments/`
- Example payload: `payload_local_filesystem.json`

#### OpenShift Mode
- Experiments stored on **PVC** mounted into the handler container
- Orchestrator calls handler over HTTP
- See `terraform/openshift_deployment/README.md`

### Validation Checklist
- Experiment YAML file is present in the configured path
- Handler can import `experiment_bofa` and `experimentvr`
- Environment variables set for the chosen mode
- Payload references correct `experiment_source`

### Compliance Notes
- Experiments should be reviewed and approved before running in production.
- Access to experiment files (S3, local disk, PVC) should be restricted.
- Logs and journals contain execution metadata and must be retained per policy.

