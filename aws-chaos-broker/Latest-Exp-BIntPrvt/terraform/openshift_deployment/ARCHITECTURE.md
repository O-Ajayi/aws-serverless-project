# Architecture Overview - OpenShift Deployment

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift Cluster                         │
│                                                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │           Orchestrator Service                       │    │
│  │  (Replaces AWS Step Functions)                       │    │
│  │  - Executes workflow state machine                   │    │
│  │  - Manages experiment execution order                │    │
│  │  - Handles retries and error recovery                │    │
│  └────────────────────────────────────────────────────┘    │
│                        │                                     │
│                        │ HTTP POST /invoke                   │
│                        ▼                                     │
│  ┌────────────────────────────────────────────────────┐    │
│  │           Handler Service                           │    │
│  │  (Replaces AWS Lambda)                              │    │
│  │  - HTTP REST API wrapper                            │    │
│  │  - Exposes handler.py function                      │    │
│  │  - Handles experiment execution                     │    │
│  └────────────────────────────────────────────────────┘    │
│                        │                                     │
│                        │ Reads/Writes                        │
│                        ▼                                     │
│  ┌────────────────────────────────────────────────────┐    │
│  │      PersistentVolumeClaim                          │    │
│  │  (Replaces S3 Bucket)                               │    │
│  │  - /app/local_only/experiments/                     │    │
│  │  - /app/local_only/journals/                        │    │
│  └────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │              ConfigMap                              │    │
│  │  - Environment configuration                        │    │
│  │  - Execution mode settings                          │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Handler Service (`handler_service.py`)

**Purpose**: HTTP wrapper for the Lambda handler function

**Key Features**:
- REST API endpoint: `POST /invoke`
- Health check: `GET /health`
- Mock Lambda context for compatibility
- Error handling and JSON response formatting

**Endpoints**:
- `GET /` - Service information
- `GET /health` - Health check
- `POST /invoke` - Invoke handler with experiment event

**Configuration**:
- Port: 8080 (configurable via `PORT` env var)
- Logging: Python logging framework
- Context: Mock Lambda context object

### 2. Orchestrator Service (`orchestrator.py`)

**Purpose**: Workflow orchestration (Step Functions replacement)

**State Machine Implementation**:
- **FirstChoiceState**: Initial state routing (pending/done)
- **MapState**: Iterates through experiment list
- **ProcessPayload**: Invokes handler service
- **ChoiceState**: Routes based on result state
- **IsPendingState**: Waits and retries if needed
- **Retry/Catch**: Error handling with configurable attempts

**Features**:
- Concurrent execution (configurable max concurrency)
- Retry logic with exponential backoff
- Result aggregation
- Error reporting

**Usage**:
```bash
python orchestrator.py \
  --payload-file payload.json \
  --handler-url http://handler-service:8080 \
  --max-concurrency 1
```

### 3. Container Images

#### Handler Service Image
- **Base**: `python:3.9-slim`
- **Size**: Optimized multi-stage build
- **Dependencies**: All local packages + requirements.txt
- **Port**: 8080
- **Health Check**: HTTP GET /health

#### Orchestrator Image
- **Base**: `python:3.9-slim`
- **Size**: Minimal (only orchestrator script)
- **Dependencies**: requests library
- **Usage**: Can run as deployment, job, or locally

### 4. Kubernetes/OpenShift Resources

#### Namespace
- `chaos-broker` - Isolated namespace for all resources

#### ConfigMap
- Configuration for both services
- Environment variables
- Execution mode settings

#### PersistentVolumeClaim
- Storage for experiments and journals
- Shared across handler pods (ReadWriteMany)
- Default size: 10Gi

#### Deployments
- **Handler Deployment**: 2 replicas (configurable)
- **Orchestrator Deployment**: 1 replica (runs on-demand)

#### Services
- **Handler Service**: ClusterIP, port 8080
- **Orchestrator Service**: ClusterIP (if running as service)

#### Route (OpenShift)
- External access to handler service
- TLS termination (edge)
- Optional: OAuth authentication

## Data Flow

### Experiment Execution Flow

```
1. User/System
   │
   ├─→ Creates payload.json with experiment list
   │
2. Orchestrator Service
   │
   ├─→ Parses payload (FirstChoiceState)
   │
   ├─→ Iterates through experiment list (MapState)
   │
   ├─→ For each experiment:
   │   │
   │   ├─→ Invokes Handler Service (ProcessPayload)
   │   │   │
   │   │   ├─→ Handler Service receives HTTP POST
   │   │   │
   │   │   ├─→ Calls handler.py handler() function
   │   │   │
   │   │   ├─→ Loads experiment from PVC
   │   │   │
   │   │   ├─→ Executes experiment
   │   │   │
   │   │   ├─→ Saves journal to PVC
   │   │   │
   │   │   └─→ Returns result
   │   │
   │   ├─→ Checks result state (ChoiceState)
   │   │
   │   ├─→ If pending: Wait and retry (IsPendingState)
   │   │
   │   └─→ If done/failed: Continue to next experiment
   │
3. Orchestrator aggregates results
   │
4. Returns final workflow result
```

## Storage Structure

```
/app/local_only/
├── experiments/
│   ├── experiment.yaml
│   ├── pod-chaos-termination.yml
│   └── ...
└── journals/
    ├── experiment_2025-11-25-14-58-00.json
    ├── pod-chaos_2025-11-25-15-30-00.json
    └── ...
```

## Networking

### Internal Communication
- Handler Service: `chaos-broker-handler.chaos-broker.svc.cluster.local:8080`
- Orchestrator → Handler: HTTP POST requests
- Service discovery via Kubernetes DNS

### External Access
- OpenShift Route: `https://chaos-broker-handler-chaos-broker.apps.example.com`
- Port Forward: `oc port-forward svc/chaos-broker-handler 8080:8080`

## Security Considerations

### OpenShift RBAC
- ServiceAccounts for each component
- Role-based access control
- Network policies (optional)

### Container Security
- Non-root user (recommended)
- Minimal base images
- Security scanning (recommended)

### Data Security
- Secrets for sensitive configuration
- PVC access controls
- Network policies for service isolation

## Scaling

### Horizontal Scaling
- Handler Service: Scale replicas based on load
- Orchestrator: Typically single instance (or use Jobs)

### Resource Limits
- Handler: 512Mi-1Gi memory, 250m-500m CPU
- Orchestrator: 256Mi-512Mi memory, 100m-250m CPU

### Autoscaling
- Configure HPA (Horizontal Pod Autoscaler) for handler service
- Based on CPU/memory metrics or custom metrics

## Monitoring & Observability

### Logging
- Container logs: `oc logs -f deployment/chaos-broker-handler`
- Centralized logging: Integrate with OpenShift logging stack

### Metrics
- Application metrics via /health endpoint
- Kubernetes metrics: CPU, memory, network
- Custom metrics: Experiment execution metrics

### Tracing
- Add OpenTelemetry/Distributed tracing
- Track request flow through orchestrator → handler

## Migration from AWS

| AWS Component | OpenShift Equivalent | Notes |
|--------------|---------------------|-------|
| Lambda Function | Handler Service | HTTP wrapper maintains compatibility |
| Step Functions | Orchestrator Service | Python implementation of state machine |
| S3 Bucket | PersistentVolumeClaim | Local storage for experiments/journals |
| CloudWatch Logs | OpenShift Logs | `oc logs` command |
| IAM Roles | ServiceAccount + RBAC | Role-based access control |
| Secrets Manager | Kubernetes Secrets | Store sensitive configuration |
| CloudWatch Metrics | Prometheus/Grafana | Metrics collection and visualization |
| API Gateway | OpenShift Route | External access with TLS |

## Comparison with AWS Deployment

### Advantages
- ✅ No vendor lock-in
- ✅ Runs on-premises
- ✅ Full control over infrastructure
- ✅ Cost-effective for local development
- ✅ Easy debugging (direct pod access)

### Considerations
- ⚠️ Requires OpenShift/Kubernetes cluster
- ⚠️ Manual scaling (or HPA configuration)
- ⚠️ No managed Step Functions (orchestrator needs maintenance)
- ⚠️ Storage management (PVC vs S3)

