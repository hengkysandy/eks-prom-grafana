# Quick Reference

Common commands for managing the EKS deployment.

## Deployment

```bash
# Deploy infrastructure
cd terraform && terraform apply -auto-approve

# Configure kubectl
aws eks update-kubeconfig --region ap-southeast-1 --name ecommerce-poc-eks

# Deploy K8s resources
cd k8s && kubectl apply -k .
```

## Access Services

```bash
# Grafana (http://localhost:3001)
kubectl port-forward -n monitoring svc/grafana 3001:3000

# Prometheus (http://localhost:9090)
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Application
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000
```

## Check Status

```bash
# Nodes
kubectl get nodes

# All pods
kubectl get pods -A

# PVCs
kubectl get pvc -n monitoring

# Services
kubectl get svc -A
```

## Logs

```bash
# Application logs
kubectl logs -n ecommerce-poc -l app=nodejs-catalog -f
kubectl logs -n ecommerce-poc -l app=python-orders -f
kubectl logs -n ecommerce-poc -l app=go-inventory -f

# Monitoring logs
kubectl logs -n monitoring -l app=prometheus -f
kubectl logs -n monitoring -l app=grafana -f
```

## Troubleshooting

```bash
# Describe pod
kubectl describe pod -n <namespace> <pod-name>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs
kubectl logs -n kube-system -l app=ebs-csi-controller
```

## Cleanup

```bash
# Delete K8s resources
kubectl delete -k k8s/

# Destroy infrastructure
cd terraform && terraform destroy -auto-approve
```

## Grafana Queries

### Prometheus (PromQL)

```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status_code=~"5.."}[5m])

# Response time p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### Loki (LogQL)

```logql
# All logs from app
{app="nodejs-catalog"}

# Error logs
{app="nodejs-catalog"} |= "error"

# JSON parsing
{app="nodejs-catalog"} | json | level="error"
```

### Tempo

Search by:
- Service Name: `nodejs-catalog`
- Tags: `http.status_code=500`
- Duration: `>100ms`
