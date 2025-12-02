# Quick Reference Guide

## Common Commands

### Access Grafana
```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
# Open: http://localhost:3001
# Login: admin/admin
```

### Access Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090
```

### Run Load Test
```bash
cd k8s
./load-test.sh 30  # 30 seconds
```

### Import Grafana Dashboards
```bash
cd k8s/grafana
./import-dashboards.sh
```

### Check Pod Status
```bash
kubectl get pods -n ecommerce-poc
kubectl get pods -n monitoring
```

### View Logs
```bash
# Kubernetes logs
kubectl logs -n ecommerce-poc <pod-name>

# CloudWatch logs
aws logs tail /aws/eks/ecommerce-poc-eks/application --follow --region ap-southeast-1
```

### Scale Services
```bash
# Scale up
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=3

# Scale down
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=1
```

### Restart Deployments
```bash
kubectl rollout restart deployment/nodejs-catalog -n ecommerce-poc
kubectl rollout restart deployment/python-orders -n ecommerce-poc
kubectl rollout restart deployment/go-inventory -n ecommerce-poc
```

### Test Endpoints
```bash
# Port-forward first
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000

# Then test
curl http://localhost:3000/health
curl http://localhost:3000/products
curl http://localhost:3000/metrics
```

## Useful Queries (Prometheus/Grafana)

### Application Metrics
```promql
# Request rate per service
rate(http_requests_total[5m])

# Total requests
sum(http_requests_total) by (service)

# Service availability
up{job=~"nodejs-catalog|python-orders|go-inventory"}

# Request duration (95th percentile)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### Kubernetes Metrics
```promql
# Pod count by namespace
count(kube_pod_info) by (namespace)

# Pod CPU requests
sum(kube_pod_container_resource_requests{resource="cpu"}) by (pod)

# Pod memory usage
sum(kube_pod_container_resource_requests{resource="memory"}) by (pod)

# Deployment replicas
kube_deployment_status_replicas{namespace="ecommerce-poc"}

# Pod restarts
kube_pod_container_status_restarts_total
```

## Troubleshooting

### Pods Pending
```bash
kubectl describe pod <pod-name> -n <namespace>
aws eks list-fargate-profiles --cluster-name ecommerce-poc-eks --region ap-southeast-1
```

### ImagePullBackOff
```bash
aws ecr describe-images --repository-name ecommerce-nodejs-catalog --region ap-southeast-1
kubectl describe pod <pod-name> -n ecommerce-poc
```

### Prometheus Not Scraping
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Check: http://localhost:9090/targets
kubectl logs -n monitoring deployment/prometheus
```

### Grafana No Data
```bash
# Check datasource
kubectl port-forward -n monitoring svc/grafana 3001:3000
# Go to: http://localhost:3001/datasources

# Test Prometheus connection
kubectl exec -n monitoring deployment/grafana -- \
  wget -qO- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/targets
```

## File Locations

### Infrastructure
- `terraform/main.tf` - EKS, ECR, networking
- `terraform/outputs.tf` - Output values
- `terraform/variables.tf` - Configuration

### Kubernetes
- `k8s/namespace.yaml` - Namespaces
- `k8s/*-deployment.yaml` - Service deployments
- `k8s/traffic-generator.yaml` - Load testing pod
- `k8s/prometheus/` - Prometheus + kube-state-metrics
- `k8s/grafana/` - Grafana + dashboards
- `k8s/fargate-logging.yaml` - CloudWatch logging

### Scripts
- `apps/build-and-push.sh` - Build and push Docker images
- `k8s/load-test.sh` - Load testing
- `k8s/grafana/import-dashboards.sh` - Import Grafana dashboards

### Documentation
- `README.md` - Main deployment guide
- `k8s/README.md` - Kubernetes documentation
- `DEPLOYMENT_SUMMARY.md` - Current state summary
- `QUICK_REFERENCE.md` - This file

## URLs

- Grafana: http://localhost:3001 (after port-forward)
- Prometheus: http://localhost:9090 (after port-forward)
- Node.js: http://localhost:3000 (after port-forward)
- Python: http://localhost:5000 (after port-forward)
- Go: http://localhost:8080 (after port-forward)

## Grafana Dashboards

- Dashboard 3119: Kubernetes Cluster Monitoring
- Dashboard 8588: Kubernetes Deployment Metrics
- Dashboard 15760: Kubernetes Views Pods
- Custom: HTTP Metrics (all services)

## Resource Limits

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|-------------|-----------|----------------|--------------|
| nodejs-catalog | 250m | 500m | 512Mi | 1Gi |
| python-orders | 250m | 500m | 512Mi | 1Gi |
| go-inventory | 200m | 400m | 256Mi | 512Mi |
| traffic-generator | 50m | 100m | 64Mi | 128Mi |
| prometheus | 250m | 500m | 512Mi | 1Gi |
| kube-state-metrics | 100m | 200m | 128Mi | 256Mi |
| grafana | 200m | 400m | 256Mi | 512Mi |

## Cost Estimate

- EKS Control Plane: ~$73/month
- Fargate (7 pods): ~$50-60/month
- NAT Gateway: ~$32/month
- CloudWatch Logs: ~$5/month
- **Total: ~$165-180/month**
