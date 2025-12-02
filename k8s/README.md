# Kubernetes Manifests

This directory contains all Kubernetes manifests for deploying the e-commerce microservices and observability stack.

## Directory Structure

```
k8s/
├── namespace.yaml                    # Namespaces: ecommerce-poc, monitoring, aws-observability
├── nodejs-deployment.yaml            # Node.js catalog service
├── python-deployment.yaml            # Python orders service
├── go-deployment.yaml                # Go inventory service
├── traffic-generator.yaml            # Alpine pod for load testing
├── fargate-logging.yaml              # Fargate CloudWatch logging config
├── kustomization.yaml                # Kustomize configuration
├── load-test.sh                      # Load testing script
├── prometheus/
│   ├── prometheus-rbac.yaml          # ServiceAccount, ClusterRole, ClusterRoleBinding
│   ├── prometheus-deployment.yaml    # Prometheus server + ConfigMap
│   └── kube-state-metrics.yaml       # Kubernetes metrics exporter
└── grafana/
    ├── grafana-deployment.yaml       # Grafana server with Prometheus datasource
    ├── import-dashboards.sh          # Script to import popular dashboards
    └── custom-dashboard.json         # Custom HTTP metrics dashboard
```

## Components

### Application Services

**Node.js Catalog Service** (`nodejs-deployment.yaml`)
- Port: 3000
- Endpoints: `/products`, `/health`, `/metrics`
- Resources: 250m CPU, 512Mi RAM

**Python Orders Service** (`python-deployment.yaml`)
- Port: 5000
- Endpoints: `/orders`, `/health`, `/metrics`
- Resources: 250m CPU, 512Mi RAM

**Go Inventory Service** (`go-deployment.yaml`)
- Port: 8080
- Endpoints: `/inventory`, `/health`, `/metrics`
- Resources: 200m CPU, 256Mi RAM

**Traffic Generator** (`traffic-generator.yaml`)
- Alpine Linux pod with sleep infinity
- Used for running load tests from inside the cluster
- Resources: 50m CPU, 64Mi RAM

### Monitoring Stack

**Prometheus** (`prometheus/prometheus-deployment.yaml`)
- Scrapes metrics from all 3 microservices
- Scrapes kube-state-metrics for Kubernetes metrics
- Port: 9090
- Resources: 250m-500m CPU, 512Mi-1Gi RAM
- Storage: emptyDir (ephemeral)

**kube-state-metrics** (`prometheus/kube-state-metrics.yaml`)
- Exposes Kubernetes object state as Prometheus metrics
- Metrics: pods, deployments, nodes, services, etc.
- Port: 8080
- Resources: 100m-200m CPU, 128Mi-256Mi RAM

**Grafana** (`grafana/grafana-deployment.yaml`)
- Pre-configured with Prometheus datasource
- Default credentials: admin/admin
- Port: 3000
- Resources: 200m-400m CPU, 256Mi-512Mi RAM
- Storage: emptyDir (ephemeral)

### Logging

**Fargate Logging** (`fargate-logging.yaml`)
- ConfigMap in `aws-observability` namespace
- Routes container logs to CloudWatch Logs
- Log group: `/aws/eks/ecommerce-poc-eks/application`

## Deployment

### Deploy Everything

```bash
# From k8s directory
kubectl apply -k .

# Watch pods starting
kubectl get pods -n ecommerce-poc -w
kubectl get pods -n monitoring -w
```

### Deploy Individual Components

```bash
# Namespaces
kubectl apply -f namespace.yaml

# Application services
kubectl apply -f nodejs-deployment.yaml
kubectl apply -f python-deployment.yaml
kubectl apply -f go-deployment.yaml
kubectl apply -f traffic-generator.yaml

# Monitoring
kubectl apply -f prometheus/prometheus-rbac.yaml
kubectl apply -f prometheus/prometheus-deployment.yaml
kubectl apply -f prometheus/kube-state-metrics.yaml
kubectl apply -f grafana/grafana-deployment.yaml

# Logging
kubectl apply -f fargate-logging.yaml
```

## Accessing Services

### Port Forwarding

```bash
# Node.js service
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000

# Python service
kubectl port-forward -n ecommerce-poc svc/python-orders 5000:5000

# Go service
kubectl port-forward -n ecommerce-poc svc/go-inventory 8080:8080

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

### Testing Endpoints

```bash
# Health checks
curl http://localhost:3000/health
curl http://localhost:5000/health
curl http://localhost:8080/health

# Business endpoints
curl http://localhost:3000/products
curl http://localhost:5000/orders
curl http://localhost:8080/inventory

# Prometheus metrics
curl http://localhost:3000/metrics
curl http://localhost:5000/metrics
curl http://localhost:8080/metrics

# Prometheus targets
curl http://localhost:9090/targets
```

## Load Testing

### Using the Load Test Script

```bash
# 30 second test (default)
./load-test.sh 30

# 60 second test
./load-test.sh 60

# 2 minute test
./load-test.sh 120
```

### Manual Load Testing

```bash
# Execute commands inside traffic-generator pod
kubectl exec -n ecommerce-poc traffic-generator -- sh -c '
for i in $(seq 1 30); do
  wget -q -O- http://nodejs-catalog.ecommerce-poc.svc.cluster.local:3000/products > /dev/null &
  wget -q -O- http://python-orders.ecommerce-poc.svc.cluster.local:5000/orders > /dev/null &
  wget -q -O- http://go-inventory.ecommerce-poc.svc.cluster.local:8080/inventory > /dev/null &
  sleep 1
done
wait
'
```

## Grafana Dashboards

### Import Dashboards Automatically

```bash
cd grafana
./import-dashboards.sh
```

This imports:
- **Dashboard 3119**: Kubernetes Cluster Monitoring via Prometheus
- **Dashboard 8588**: Kubernetes Deployment Statefulset Daemonset metrics
- **Dashboard 15760**: Kubernetes Views Pods

### Import Dashboards Manually

1. Access Grafana: http://localhost:3001
2. Login: admin/admin
3. Click **+** → **Import**
4. Enter dashboard ID: 3119, 8588, or 15760
5. Select **Prometheus** as data source
6. Click **Import**

### Available Metrics

**Application Metrics:**
- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request duration
- `up` - Service availability

**Kubernetes Metrics (from kube-state-metrics):**
- `kube_pod_info` - Pod information
- `kube_pod_status_phase` - Pod status
- `kube_deployment_status_replicas` - Deployment replicas
- `kube_deployment_status_replicas_available` - Available replicas
- `kube_pod_container_resource_requests` - Resource requests
- `kube_pod_container_resource_limits` - Resource limits

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check Fargate profiles
aws eks list-fargate-profiles --cluster-name ecommerce-poc-eks --region ap-southeast-1

# Verify namespace matches Fargate profile selector
aws eks describe-fargate-profile \
  --cluster-name ecommerce-poc-eks \
  --fargate-profile-name ecommerce-app-profile \
  --region ap-southeast-1
```

### ImagePullBackOff

```bash
# Check image exists in ECR
aws ecr describe-images --repository-name ecommerce-nodejs-catalog --region ap-southeast-1

# Verify image tag in deployment
kubectl get deployment nodejs-catalog -n ecommerce-poc -o yaml | grep image:

# Check pod events
kubectl describe pod <pod-name> -n ecommerce-poc
```

### Prometheus Not Scraping

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/targets

# Check Prometheus logs
kubectl logs -n monitoring deployment/prometheus

# Verify service labels match scrape config
kubectl get pods -n ecommerce-poc --show-labels
```

### Grafana Shows No Data

```bash
# Check Prometheus datasource
kubectl port-forward -n monitoring svc/grafana 3001:3000
# Open: http://localhost:3001/datasources

# Test Prometheus connection
kubectl exec -n monitoring deployment/grafana -- \
  wget -qO- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/targets

# Check if kube-state-metrics is running
kubectl get pods -n monitoring | grep kube-state-metrics

# Verify metrics are being collected
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Query: up{job="kube-state-metrics"}
```

### CloudWatch Logs Not Appearing

```bash
# Check aws-observability namespace exists
kubectl get namespace aws-observability

# Verify ConfigMap
kubectl get configmap -n aws-observability aws-logging -o yaml

# Check pod logs directly
kubectl logs -n ecommerce-poc <pod-name>

# Verify Fargate profile includes aws-observability namespace
aws eks describe-fargate-profile \
  --cluster-name ecommerce-poc-eks \
  --fargate-profile-name ecommerce-app-profile \
  --region ap-southeast-1
```

## Scaling

```bash
# Scale up
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=3
kubectl scale deployment python-orders -n ecommerce-poc --replicas=3
kubectl scale deployment go-inventory -n ecommerce-poc --replicas=3

# Scale down
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=1
kubectl scale deployment python-orders -n ecommerce-poc --replicas=1
kubectl scale deployment go-inventory -n ecommerce-poc --replicas=1

# Check status
kubectl get pods -n ecommerce-poc
kubectl get hpa -n ecommerce-poc  # No HPA configured in this PoC
```

## Cleanup

```bash
# Delete all resources
kubectl delete -k .

# Or delete by namespace
kubectl delete namespace ecommerce-poc
kubectl delete namespace monitoring
kubectl delete namespace aws-observability

# Verify deletion
kubectl get pods --all-namespaces
```

## Notes

- All services use ClusterIP (internal only)
- No ingress controller configured
- Access via kubectl port-forward only
- Storage is ephemeral (emptyDir)
- No persistent volumes configured
- Fargate pods take 30-60 seconds to start
- DaemonSets don't work on Fargate
- Node-level metrics not available on Fargate
