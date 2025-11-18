# Local-Only Chaos Experiment Sample

Use this directory when testing the Lambda handler with `local_mode=true`
on your laptop or workstation. It contains:

- `experiments/experiment.yaml` – sample experiment file referenced by the
  local payload.
- `payload_local_filesystem.json` – ready-to-use event payload.

## Directory Structure

```
local_only/
├── experiments/
│   └── experiment.yaml
└── payload_local_filesystem.json
```

## Quick Start

```bash
cd Experiment-Broker-Module/experiment_code/lambda
source chaos-venv/bin/activate

export local_mode=true
export experiment_source="$(pwd)/local_only/experiments/experiment.yaml"

python handler.py
```

You should see log messages indicating the handler loaded the experiment from
the local filesystem and skipped AWS service calls.

## Sample Payload

Invoke the handler (or Step Function) with:

```json
{
  "local_mode": true,
  "experiment_source": "local_only/experiments/experiment.yaml",
  "configuration": {
    "cluster_name": "local-kube",
    "namespace": "chaos-testing",
    "pod_label_selector": "app=demo"
  }
}
```

> When using the Lambda console, convert `experiment_source` to an absolute path
> visible to the execution environment (for local tests this is your filesystem;
> AWS Lambda cannot access it, so keep `local_mode=false` in the cloud).

