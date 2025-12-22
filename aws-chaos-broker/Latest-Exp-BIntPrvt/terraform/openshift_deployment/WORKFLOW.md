# Workflow: Orchestrator → Handler → Persistent Volume

This document explains the complete workflow for running chaos experiments on OpenShift.

## Architecture Flow

```
┌─────────────────┐
│  User/System    │
│  Creates Payload│
└────────┬────────┘
         │
         │ POST /execute
         │ (JSON payload)
         ▼
┌─────────────────────────────┐
│  Orchestrator Service       │
│  (HTTP Service on :8081)    │
│  - Accepts workflow payload │
│  - Manages experiment list  │
│  - Invokes handler service  │
└────────┬────────────────────┘
         │
         │ For each experiment:
         │ POST /invoke
         │ (experiment config)
         ▼
┌─────────────────────────────┐
│  Handler Service            │
│  (HTTP Service on :8080)    │
│  - Receives experiment config│
│  - Reads experiment.yaml    │
│  - Executes experiment      │
│  - Saves journal            │
└────────┬────────────────────┘
         │
         │ Reads from / Writes to
         ▼
┌─────────────────────────────┐
│  PersistentVolumeClaim      │
│  /app/local_only/           │
│  ├── experiments/           │
│  │   └── experiment.yaml    │
│  └── journals/              │
│      └── experiment_*.json  │
└─────────────────────────────┘
```

## Step-by-Step Workflow

### 1. Store Experiment Files in Persistent Volume

Experiment YAML files must be stored in the persistent volume before execution.

**Option A: Upload via kubectl/oc**
```bash
# Upload a single experiment file
./scripts/upload-experiment.sh /path/to/experiment.yaml

# Upload multiple files
./scripts/upload-experiment.sh experiment1.yaml experiment2.yaml
```

**Option B: Copy directly to running pod**
```bash
# Get handler pod name
POD_NAME=$(oc get pods -n chaos-broker -l component=handler -o jsonpath='{.items[0].metadata.name}')

# Copy experiment file
oc cp experiment.yaml chaos-broker/$POD_NAME:/app/local_only/experiments/experiment.yaml
```

**Option C: Use initContainer or ConfigMap**
- Create a ConfigMap with experiment files (for small files)
- Use an initContainer to copy files from a source

### 2. Create Payload for Orchestrator

Create a JSON payload that references experiment files in the persistent volume:

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

**Key Points:**
- `experiment_source`: Relative filename or full path to file in persistent volume
  - Relative: `"experiment.yaml"` → resolved to `/app/local_only/experiments/experiment.yaml`
  - Absolute: `"/app/local_only/experiments/experiment.yaml"` → used as-is
- `openshift_storage_path`: Base path for persistent volume (default: `/app/local_only`)
- `local_mode`: Must be `"openshift"` for OpenShift deployment

### 3. Send Payload to Orchestrator

**Option A: HTTP POST to Orchestrator Service**
```bash
# Port-forward orchestrator service
oc port-forward -n chaos-broker svc/chaos-broker-orchestrator 8081:8081

# Send payload
curl -X POST http://localhost:8081/execute \
  -H "Content-Type: application/json" \
  -d @payload.json
```

**Option B: Via OpenShift Route**
```bash
# Get route URL
ORCHESTRATOR_URL=$(oc get route chaos-broker-orchestrator -n chaos-broker -o jsonpath='{.spec.host}')

# Send payload
curl -X POST https://$ORCHESTRATOR_URL/execute \
  -H "Content-Type: application/json" \
  -d @payload.json
```

**Option C: From within cluster**
```bash
# Exec into a pod and use internal service URL
oc exec -it deployment/chaos-broker-orchestrator -n chaos-broker -- \
  curl -X POST http://localhost:8081/execute \
    -H "Content-Type: application/json" \
    -d @payload.json
```

### 4. Orchestrator Processes Workflow

1. **Receives payload** at `POST /execute`
2. **Normalizes paths**: Resolves relative `experiment_source` paths to `/app/local_only/experiments/`
3. **Iterates through experiments**: For each experiment in the list:
   - Calls handler service: `POST http://chaos-broker-handler:8080/invoke`
   - Passes experiment configuration with normalized path
   - Waits for response
   - Handles retries if needed
4. **Returns aggregated results**

### 5. Handler Executes Experiment

1. **Receives invocation** at `POST /invoke`
2. **Parses execution mode**: Sets `local_mode="openshift"`
3. **Loads experiment**: Reads YAML from `/app/local_only/experiments/{experiment_source}`
4. **Executes experiment**: Runs chaos actions and probes
5. **Saves journal**: Writes results to `/app/local_only/journals/experiment_*.json`
6. **Returns result**: Includes execution state and journal

### 6. Results Saved to Persistent Volume

- **Journals**: Saved to `/app/local_only/journals/` with timestamped filenames
- **Format**: JSON files with experiment execution results
- **Access**: Retrieve via pod exec or volume mount

## Example: Complete Workflow

```bash
# 1. Upload experiment file
./scripts/upload-experiment.sh /path/to/pod-chaos-termination.yml

# 2. Create payload file
cat > my-payload.json <<EOF
{
  "Payload": {
    "list": [
      {
        "local_mode": "openshift",
        "experiment_source": "pod-chaos-termination.yml",
        "openshift_storage_path": "/app/local_only",
        "configuration": {
          "cluster_name": "my-eks-cluster",
          "namespace": "default",
          "pod_label_selector": "app=nginx"
        }
      }
    ],
    "state": "pending"
  }
}
EOF

# 3. Port-forward orchestrator service
oc port-forward -n chaos-broker svc/chaos-broker-orchestrator 8081:8081 &

# 4. Execute workflow
curl -X POST http://localhost:8081/execute \
  -H "Content-Type: application/json" \
  -d @my-payload.json

# 5. Check results
POD_NAME=$(oc get pods -n chaos-broker -l component=handler -o jsonpath='{.items[0].metadata.name}')
oc exec -n chaos-broker $POD_NAME -- ls -la /app/local_only/journals/
```

## Path Resolution Logic

### Orchestrator Service
- Accepts relative or absolute paths in `experiment_source`
- Normalizes to: `/app/local_only/experiments/{filename}`
- Sets `openshift_storage_path: /app/local_only` if not provided

### Handler Service
- In OpenShift mode, reads from persistent volume
- If `experiment_source` is relative: joins with `openshift_storage_path/experiments/`
- If `experiment_source` is absolute: uses as-is
- Default storage path: `/app/local_only`

## Persistent Volume Structure

```
/app/local_only/          (Mounted from PVC: chaos-broker-storage)
├── experiments/          (Store experiment YAML files here)
│   ├── experiment.yaml
│   ├── pod-chaos-termination.yml
│   └── ...
└── journals/            (Experiment execution journals)
    ├── experiment_2025-11-25-14-58-00.json
    └── ...
```

## Troubleshooting

### Experiment File Not Found

```bash
# Verify file exists in pod
oc exec -n chaos-broker deployment/chaos-broker-handler -- \
  ls -la /app/local_only/experiments/

# Check mount point
oc describe pod -n chaos-broker -l component=handler | grep -A 5 "Mounts:"
```

### Path Resolution Issues

- Use relative paths: `"experiment.yaml"` (recommended)
- Or absolute paths: `"/app/local_only/experiments/experiment.yaml"`
- Ensure `openshift_storage_path` matches the mount point

### Handler Can't Read File

```bash
# Check file permissions
oc exec -n chaos-broker deployment/chaos-broker-handler -- \
  ls -la /app/local_only/experiments/experiment.yaml

# Verify handler can access
oc exec -n chaos-broker deployment/chaos-broker-handler -- \
  cat /app/local_only/experiments/experiment.yaml
```

