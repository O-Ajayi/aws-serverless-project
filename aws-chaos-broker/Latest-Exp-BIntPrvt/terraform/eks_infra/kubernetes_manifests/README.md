# Kubernetes Manifests for EKS Cluster

This directory contains Kubernetes manifests for deploying sample applications in the EKS cluster for chaos testing.

## Nginx Deployment

The `nginx-deployment.yaml` file contains:

1. **Deployment**: 3 replicas of nginx pods
2. **ClusterIP Service**: Internal service for pod access
3. **LoadBalancer Service**: External service with AWS ELB
4. **ConfigMap**: Nginx configuration

### Features

- **3 Replicas**: High availability with 3 nginx pods
- **Health Checks**: Liveness and readiness probes
- **Resource Limits**: CPU and memory constraints
- **Labels**: Proper labeling for chaos experiment targeting
- **ConfigMap**: Custom nginx configuration
- **Two Service Types**: 
  - ClusterIP for internal access
  - LoadBalancer for external access via AWS ELB

## Deployment Instructions

### Step 1: Ensure kubectl is configured

```bash
aws eks update-kubeconfig --region us-east-1 --name chaos-broker-eks
kubectl get nodes
```

### Step 2: Deploy Nginx

```bash
cd terraform/eks_infra/kubernetes_manifests
kubectl apply -f nginx-deployment.yaml
```

### Step 3: Verify Deployment

```bash
# Check deployment status
kubectl get deployment nginx-deployment

# Check pods
kubectl get pods -l app=nginx

# Check services
kubectl get svc nginx-service
kubectl get svc nginx-service-loadbalancer

# Check pod details
kubectl describe pod -l app=nginx

# View pod logs
kubectl logs -l app=nginx --tail=50
```

### Step 4: Test the Service

```bash
# Get the LoadBalancer external IP
kubectl get svc nginx-service-loadbalancer

# Test internal service (from within cluster)
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://nginx-service.default.svc.cluster.local

# Test external service (get EXTERNAL-IP from step above)
curl http://<EXTERNAL-IP>/
```

## Using with Chaos Experiments

The nginx deployment is configured with the label selector `app=nginx`, which matches the sample chaos experiment configuration:

```yaml
configuration:
  pod_label_selector: "app=nginx"
```

### Example: Run Pod Termination Chaos Experiment

```bash
# Ensure pods are running
kubectl get pods -l app=nginx

# Run the chaos experiment
cd Experiment-Broker-Module/experiment_code/lambda
export local_mode=true
export experiment_source=../../../../terraform/eks_infra/experiments/pod-chaos-termination.yml
export bucket_name=dummy
export output_bucket=dummy
export output_path=dummy
python handler.py

# Verify pods recovered
kubectl get pods -l app=nginx
```

## Scaling

### Scale Up

```bash
kubectl scale deployment nginx-deployment --replicas=5
```

### Scale Down

```bash
kubectl scale deployment nginx-deployment --replicas=2
```

### Autoscaling (HPA)

Create a Horizontal Pod Autoscaler:

```bash
kubectl autoscale deployment nginx-deployment --cpu-percent=70 --min=3 --max=10
kubectl get hpa
```

## Cleanup

To remove all resources:

```bash
kubectl delete -f nginx-deployment.yaml
```

Or delete individual resources:

```bash
kubectl delete deployment nginx-deployment
kubectl delete svc nginx-service
kubectl delete svc nginx-service-loadbalancer
kubectl delete configmap nginx-config
```

## Troubleshooting

### Pods not starting

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Service not accessible

```bash
# Check service endpoints
kubectl get endpoints nginx-service

# Check service details
kubectl describe svc nginx-service

# Test from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://nginx-service.default.svc.cluster.local
```

### LoadBalancer not getting external IP

```bash
# Check service status
kubectl get svc nginx-service-loadbalancer

# Check AWS LoadBalancer Controller logs (if installed)
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify IAM permissions for LoadBalancer Controller
```

## Customization

### Update Image Version

Edit `nginx-deployment.yaml`:

```yaml
image: nginx:1.26-alpine  # Change version
```

### Change Replica Count

```yaml
replicas: 5  # Change number of replicas
```

Or use kubectl:

```bash
kubectl scale deployment nginx-deployment --replicas=5
```

### Modify Resource Limits

Edit the resources section in `nginx-deployment.yaml`:

```yaml
resources:
  requests:
    memory: "128Mi"  # Increase memory request
    cpu: "200m"      # Increase CPU request
  limits:
    memory: "256Mi"  # Increase memory limit
    cpu: "500m"      # Increase CPU limit
```

## Monitoring

### View Pod Metrics

```bash
# CPU and Memory usage
kubectl top pods -l app=nginx

# Node metrics
kubectl top nodes
```

### Watch Pod Status

```bash
# Watch pods in real-time
kubectl get pods -l app=nginx -w

# Watch all resources
kubectl get all -l app=nginx -w
```

## Security Considerations

1. **RBAC**: Ensure proper RBAC policies are set for the namespace
2. **Network Policies**: Consider adding network policies to restrict traffic
3. **Pod Security Standards**: Apply pod security standards if enabled
4. **Image Scanning**: Use trusted base images (nginx:alpine is recommended)
5. **Resource Limits**: Always set resource limits to prevent resource exhaustion

## Next Steps

1. **Deploy Monitoring**: Set up Prometheus and Grafana for monitoring
2. **Add Ingress**: Configure Ingress controller for better routing
3. **Enable TLS**: Add TLS certificates for HTTPS
4. **Set up Logging**: Configure centralized logging (CloudWatch, ELK, etc.)
5. **Create More Workloads**: Deploy additional applications for chaos testing

## References

- [Kubernetes Deployment Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Service Documentation](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Nginx Documentation](https://nginx.org/en/docs/)

