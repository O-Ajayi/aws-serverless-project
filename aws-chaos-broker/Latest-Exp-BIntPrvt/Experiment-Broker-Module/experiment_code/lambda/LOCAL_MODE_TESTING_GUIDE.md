# Local Mode Testing Guide

Use this guide to exercise the handler across every supported execution mode.

## Modes at a Glance

| `local_mode` value | Execution mode | Experiment source                             | AWS Services | Typical use case                     |
|--------------------|----------------|-----------------------------------------------|--------------|--------------------------------------|
| `false` / omitted  | `aws`          | S3 (`bucket_name` + `experiment_source`)       | Enabled      | Production Lambda execution          |
| `true`             | `local`        | Local filesystem path                          | Skipped      | Desktop / laptop test harness        |
| `"openshift"`     | `openshift`    | `${openshift_storage_path}/${experiment_source}` | Skipped    | On-prem OpenShift or CRC             |

The handler sets `execution_mode`, `execution_provider`, and `skip_aws_services`
automatically based on this value.

---

## Option 1: Use the Test Script

```bash
cd Experiment-Broker-Module/experiment_code/lambda
./test_local_mode.sh
```

The script activates the virtual environment, configures `PYTHONPATH`, loads
the local sample payload, and prints the result.

---

## Option 2: Local Filesystem (`local_mode=true`)

```bash
cd Experiment-Broker-Module/experiment_code/lambda
source chaos-venv/bin/activate

export local_mode=true
export experiment_source="$(pwd)/local_only/experiments/experiment.yaml"

python handler.py
```

The payload used is `local_only/payload_local_filesystem.json`. No AWS
credentials are required; the handler simply reads the YAML from disk.

---

## Option 3: OpenShift / On-Prem (`local_mode="openshift"`)

```bash
cd Experiment-Broker-Module/experiment_code/lambda
source chaos-venv/bin/activate

export local_mode=openshift
export openshift_storage_path=/mnt/openshift/chaos-files   # adjust for your mount
export experiment_source="experiments/pod-chaos-termination.yml"

python handler.py
```

This resolves the experiment path to:
```
/mnt/openshift/chaos-files/experiments/pod-chaos-termination.yml
```

Use `payload_openshift.json` as a template when invoking via CLI or Step
Functions.

> Ensure the OpenShift storage path is mounted into the environment running the
> handler (e.g. pod volume, CRC shared folder).

---

## AWS Mode (`local_mode=false`)

1. Upload the experiment YAML to S3:
   ```bash
   aws s3 cp ../../../terraform/eks_infra/experiments/pod-chaos-termination.yml \
       s3://experiment-bucket-111222333/experiments/pod-chaos-termination.yml
   ```
2. Invoke the handler with `payload_aws.json` (locally or in the Lambda
   console).

---

## Running via Python

```bash
source chaos-venv/bin/activate
python -c '
import json
from handler import handler

with open("local_only/payload_local_filesystem.json") as f:
    event = json.load(f)

class MockContext:
    function_name = "test"
    aws_request_id = "local-test"

print(json.dumps(handler(event, MockContext()), indent=2))
'
```

Swap the payload file for `payload_openshift.json` or `payload_aws.json` as
needed.

---

## Troubleshooting

- **Experiment file not found** – check the absolute path printed in the logs.
- **Unexpected AWS calls** – ensure `local_mode` is `true` or `"openshift"`.
- **Import errors** – run `./setup.sh` and export
  `PYTHONPATH="$(cd ../.. && pwd):$PYTHONPATH"`.

---

## Related Resources

- `local_only/README.md` – curated local-only samples.
- `openshift_local/README.md` – OpenShift/CRC workflow.
- `payload_*.json` – ready-made payloads for AWS, local, and OpenShift modes.

