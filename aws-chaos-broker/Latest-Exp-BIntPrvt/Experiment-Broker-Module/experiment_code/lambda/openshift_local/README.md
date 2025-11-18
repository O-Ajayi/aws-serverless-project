# Local OpenShift / Kubernetes Testing

This guide walks you through running the Lambda handler in `local_mode=true`
against a local OpenShift (or vanilla Kubernetes) cluster.

The approach works with:

- Red Hat CodeReady Containers / local OpenShift
- A remote OpenShift cluster you can reach with `oc`
- Minikube, kind, or k3s (any kubeconfig-compatible cluster)

The handler never calls AWS when `local_mode=true` — all you need is access to
the cluster's API and the experiment YAML on disk.

---

## 1. Prepare a Cluster

### Option A: CodeReady Containers (OpenShift)
```bash
crc setup
crc start
eval $(crc oc-env)       # adds `oc` to your PATH
oc login -u kubeadmin -p <password> https://api.crc.testing:6443
```

### Option B: Red Hat OpenShift (Remote)
```bash
oc login https://api.<cluster-domain>:6443 --username=<user> --password=<pass>
```

### Option C: Minikube / kind / k3s
```bash
minikube start
# or:
kind create cluster
```

> The handler only needs a kubeconfig context. For OpenShift you'll still use
`oc`, but Kubernetes tools work the same way once logged in.

---

## 2. Deploy the Sample Workload

We provide an nginx deployment and services you can re-use for chaos testing.

```bash
cd terraform/eks_infra/kubernetes_manifests
kubectl apply -f nginx-deployment.yaml

kubectl get pods -l app=nginx
kubectl get svc nginx-service
```

You now have three nginx pods with labels the sample experiment expects.

---

## 3. Configure Environment Variables

The handler reads environment variables when you run it directly (e.g.
`python handler.py` or `python dev_exec.py`). Only the relevant ones need to be
set for local mode.

```bash
cd Experiment-Broker-Module/experiment_code/lambda
source chaos-venv/bin/activate

# Required for local_mode
export local_mode=true
export experiment_source=$(pwd)/../../../../terraform/eks_infra/experiments/pod-chaos-termination.yml

# Optional, but helpful to document the target cluster
export execution_provider=openshift
export openshift_cluster_name=ocp-dev
export openshift_namespace=chaos-testing
export openshift_api_server=https://api.crc.testing:6443   # adjust for your cluster

# You can leave AWS-specific variables unset in local mode
unset bucket_name
unset output_bucket
unset output_path
unset secret_arn
```

The handler automatically sets:

```json
{
  "execution_mode": "local",
  "execution_provider": "openshift",
  "skip_aws_services": true,
  "on_prem_target": {
    "provider": "openshift",
    "cluster_name": "ocp-dev",
    "namespace": "chaos-testing",
    "api_server": "https://api.crc.testing:6443"
  }
}
```

---

## 4. Run the Handler Locally

```bash
# Direct execution (calls handler(event, None) inside __main__)
python handler.py

# or use dev_exec, which prints the event and result
python dev_exec.py
```

You should see log output similar to:

```
[INFO] VS Runner Lite attempting to load experiment: /.../pod-chaos-termination.yml
[INFO] Loading experiment from local file: /.../pod-chaos-termination.yml
[INFO] Local/on-prem mode: Skipping S3 output upload
```

The returned event will contain the experiment journal in `response`.

---

## 5. Optional: Use the Test Script

```bash
./test_local_mode.sh
```

This script:
1. Activates the virtual environment
2. Sets `local_mode=true` and the experiment file path
3. Imports the handler
4. Invokes the handler with a local-mode payload

Feel free to customise the script with your own paths and environment details.

---

## 6. Clean Up

Remove the sample workload if you no longer need it:

```bash
kubectl delete -f terraform/eks_infra/kubernetes_manifests/nginx-deployment.yaml
```

For CodeReady Containers:
```bash
crc stop
crc delete
```

For kind:
```bash
kind delete cluster
```

For Minikube:
```bash
minikube delete
```

---

## Next Steps

- Build your own experiments that target your OpenShift workloads using the same
  `local_mode=true` workflow.
- Keep the experiment YAMLs under version control so you can pass specific files
  to `experiment_source`.
- When you’re ready to run the same experiment in AWS, upload the YAML to S3,
  set `local_mode=false`, and supply the bucket/key.

Need help automating any of this? Let us know!

