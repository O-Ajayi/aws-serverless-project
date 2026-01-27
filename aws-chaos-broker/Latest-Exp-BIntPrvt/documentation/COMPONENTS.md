## Component Descriptions

This document describes key components for compliance review.

### Experiment Generator
- Builds experiment YAML files from templates or manual input.
- Ensures required fields are present (title, description, method).
- Validates allowed actions and probes before submission.

### Experiment Broker
- Orchestrates execution of multiple experiments.
- Controls retries, concurrency, and status transitions.
- Routes requests to the handler service or Lambda.

### Handler
- Executes a single experiment payload.
- Loads experiment files from configured storage.
- Invokes actions/probes through `experiment_bofa` / `experimentvr`.

### Sample Actions
- **Terminate pod**: Simulate application failure in Kubernetes.
- **Block network traffic**: Validate fault tolerance under connectivity loss.
- **CPU/Memory stress**: Validate resource saturation handling.

### Sample Probes
- **Health check**: Validate service endpoint availability.
- **Latency probe**: Measure response time after fault injection.
- **Resource metrics**: Confirm resource usage stabilizes post-recovery.

### Monitoring and Alerting
- **AWS Mode**: CloudWatch Logs, CloudWatch Alarms, AWS SNS notifications.
- **OpenShift**: Pod logs, events, Prometheus/Grafana integrations.
- **Local Mode**: Console logs and execution journals on disk.

### Audit and Compliance
- Experiment definitions stored in controlled locations.
- Execution journals preserved for auditing.
- Access controls enforced through IAM/RBAC.

