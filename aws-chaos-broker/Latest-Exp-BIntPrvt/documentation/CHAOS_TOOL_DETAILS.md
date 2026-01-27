## Chaos Tool Details

This document describes the Chaos Tool implementation used by the Experiment Broker.

### What It Is
The Chaos Tool is a set of Python packages (`experiment_bofa`, `experimentvr`) that provide:
- **Actions**: Operations that change system state (e.g., terminate pod, block network).
- **Probes**: Checks that observe system behavior (e.g., service health).

### Primary Packages
- `experiment_bofa`: Core implementation for AWS, Kubernetes, and platform actions/probes.
- `experimentvr`: Additional patterns and reusable chaos utilities.

### Actions and Probes Layout
Examples of the package structure:
- `experiment_bofa.ec2.actions`
- `experiment_bofa.k8s.actions`
- `experiment_bofa.s3.probes`
- `experiment_bofa.network.actions`

### Execution Flow
1. Handler reads experiment YAML.
2. Actions/probes are imported dynamically by Python module path.
3. Execution results are recorded to journals.

### Common Use Cases
- Inject latency or packet loss in network paths.
- Terminate pods in a namespace to validate recovery.
- Stress CPU or memory on target nodes.
- Validate service endpoints with probes after fault injection.

### Payload Considerations
Payloads control:
- **Local/AWS/OpenShift mode**
- **Experiment source location**
- **Target configuration** (cluster name, namespace, selectors)

### Safety and Compliance
- Use non-production accounts for destructive tests.
- Require approval workflows for production experiments.
- Restrict actions with RBAC and IAM.

