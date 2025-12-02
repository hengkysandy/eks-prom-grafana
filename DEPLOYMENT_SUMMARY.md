# Deployment Summary

## Current State (as of 2025-12-02)

This document summarizes the complete deployed infrastructure and applications.

## Infrastructure (Terraform)

### AWS Resources Created

**EKS Cluster:**
- Name: `ecommerce-poc-eks`
- Version: 1.31
- Region: ap-southeast-1
- Compute: Fargate Spot only (no EC2 nodes)

**Networking:**
- VPC: Default VPC (vpc-0a1b2c3d4e5f6g7h8)
- Private Subnets: 3 subnets across 3 AZs
  - 172.31.128.0/20 (ap-southeast-1a)
  - 172.31.144.0/20 (ap-southeast-1b)
  - 172.31.160.0/20 (ap-southeast-1c)
- NAT Gateway: 1 NAT Gateway with Elastic IP
- VPC Endpoints: STS endpoint for IAM authentication

**Fargate Profiles:**
- `ecommerce-app-profile`: Covers ecommerce-poc namespace
- `kube-system-profile`: Covers kube-system namespace
- `monitoring-profile`: Covers monitoring namespace
- `aws-observability-profile`: Covers aws-observability namespace

**ECR Repositories:**
- ecommerce-nodejs-catalog
- ecommerce-python-orders
- ecommerce-go-inventory

**CloudWatch:**
- Log Group: `/aws/eks/ecommerce-poc-eks/application`
- Retention: 7 days

**IAM Roles:**
- EKS Cluster Role
- Fargate Pod Execution Role
- Prometheus ServiceAccount Role (IRSA)

## Applications Deployed

### Microservices (namespace: ecommerce-poc)

**1. Node.js Catalog Service**
- Image: 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-nodejs-catalog:latest
- Port: 3000
- Endpoints: /products, /health, /metrics
- Resources: 250m CPU, 512Mi RAM
- Replicas: 1

**2. Python Orders Service**
- Image: 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-python-orders:latest
- Port: 5000
- Endpoints: /orders, /health, /metrics
- Resources: 250m CPU, 512Mi RAM
- Replicas: 1

**3. Go Inventory Service**
- Image: 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-go-inventory:latest
- Port: 8080
- Endpoints: /inventory, /health, /metrics
- Resources: 200m CPU, 256Mi RAM
- Replicas: 1

**4. Traffic Generator**
- Image: alpine:latest
- Purpose: Load testing from inside cluster
- Resources: 50m CPU, 64Mi RAM

### Monitoring Stack (namespace: monitoring)

**1. Prometheus**
- Image: prom/prometheus:v2.48.0
- Port: 9090
- Scrape Targets:
  - nodejs-catalog (port 3000)
  - python-orders (port 5000)
  - go-inventory (port 8080)
  - kube-state-metrics (port 8080)
- Resources: 250m-500m CPU, 512Mi-1Gi RAM
- Storage: emptyDir (ephemeral)

**2. kube-state-metrics**
- Image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.1
- Port: 8080
- Purpose: Exposes Kubernetes object metrics
- Resources: 100m-200m CPU, 128Mi-256Mi RAM

**3. Grafana**
- Image: grafana/grafana:10.2.0
- Port: 3000
- Credentials: admin/admin
- Datasource: Prometheus (pre-configured)
- Resources: 200m-400m CPU, 256Mi-512Mi RAM
- Storage: emptyDir (ephemeral)

**Grafana Dashboards Imported:**
- Dashboard 3119: Kubernetes Cluster Monitoring via Prometheus
- Dashboard 8588: Kubernetes Deployment Statefulset Daemonset metrics
- Dashboard 15760: Kubernetes Views Pods
- Custom Dashboard: HTTP Metrics for all 3 microservices

### Logging (namespace: aws-observability)

**Fargate Logging Configuration**
- Output: CloudWatch Logs
- Log Group: `/aws/eks/ecommerce-poc-eks/application`
- Format: JSON
- All container logs from ecommerce-poc namespace

## Metrics Collected

### Application Metrics (Prometheus)

**HTTP Metrics:**
- `http_requests_total{service, method, route, status}` - Total requests
- `http_request_duration_seconds{service, method, route}` - Request duration histogram
- `up{job, instance}` - Service availability

**Custom Labels:**
- Node.js: Uses `route` label
- Python: Uses `endpoint` label
- Go: Uses `route` label

### Kubernetes Metrics (kube-state-metrics)

**Pod Metrics:**
- `kube_pod_info` - Pod metadata
- `kube_pod_status_phase` - Pod lifecycle phase
- `kube_pod_container_resource_requests` - CPU/Memory requests
- `kube_pod_container_resource_limits` - CPU/Memory limits
- `kube_pod_container_status_restarts_total` - Container restarts

**Deployment Metrics:**
- `kube_deployment_status_replicas` - Desired replicas
- `kube_deployment_status_replicas_available` - Available replicas
- `kube_deployment_status_replicas_unavailable` - Unavailable replicas

**Node Metrics:**
- `kube_node_info` - Node metadata (limited on Fargate)
- `kube_node_status_condition` - Node conditions

## Access Methods

### Local Access (kubectl port-forward)

```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000
# Access: http://localhost:3001

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Access: http://localhost:9090

# Node.js Service
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000
# Access: http://localhost:3000

# Python Service
kubectl port-forward -n ecommerce-poc svc/python-orders 5000:5000
# Access: http://localhost:5000

# Go Service
kubectl port-forward -n ecommerce-poc svc/go-inventory 8080:8080
# Access: http://localhost:8080
```

### CloudWatch Logs

```bash
# View logs
aws logs tail /aws/eks/ecommerce-poc-eks/application --follow --region ap-southeast-1

# Or via AWS Console
# CloudWatch → Log Groups → /aws/eks/ecommerce-poc-eks/application
```

## Load Testing

### Quick Test
```bash
cd k8s
./load-test.sh 30  # 30 seconds
```

### Custom Duration
```bash
./load-test.sh 60   # 60 seconds
./load-test.sh 120  # 2 minutes
```

## Cost Breakdown (Monthly Estimate)

| Service | Cost |
|---------|------|
| EKS Control Plane | ~$73 |
| Fargate (7 pods) | ~$50-60 |
| NAT Gateway | ~$32 |
| Data Transfer | ~$5-10 |
| CloudWatch Logs | ~$5 |
| **Total** | **~$165-180/month** |

## Known Limitations

1. **No Persistent Storage**: All data is ephemeral (emptyDir volumes)
2. **No Autoscaling**: Manual scaling only (no HPA/VPA)
3. **No Ingress**: Access via kubectl port-forward only
4. **No TLS**: HTTP only (no HTTPS)
5. **No DaemonSets**: Fargate doesn't support DaemonSets
6. **Limited Node Metrics**: Fargate doesn't expose node-level metrics
7. **Single Region**: No multi-region setup
8. **No Backup**: No disaster recovery configured

## What Works

✅ 3 microservices running on Fargate Spot
✅ Prometheus scraping all services
✅ kube-state-metrics exposing Kubernetes metrics
✅ Grafana with 4 dashboards showing metrics
✅ CloudWatch Logs integration
✅ Load testing from traffic-generator pod
✅ Health checks and metrics endpoints
✅ Service discovery via Kubernetes DNS
✅ IAM authentication via IRSA
✅ Private subnets with NAT Gateway

## What Doesn't Work

❌ Node-level metrics (disk, network on nodes) - Fargate limitation
❌ DaemonSets (e.g., Fluent Bit) - Fargate limitation
❌ Direct internet access to services - No ingress configured
❌ Persistent data - No PVs configured
❌ Automatic scaling - No HPA configured

## Troubleshooting Commands

```bash
# Check all pods
kubectl get pods --all-namespaces

# Check specific namespace
kubectl get pods -n ecommerce-poc
kubectl get pods -n monitoring

# Check pod logs
kubectl logs -n ecommerce-poc <pod-name>
kubectl logs -n monitoring <pod-name>

# Check pod events
kubectl describe pod -n ecommerce-poc <pod-name>

# Check services
kubectl get svc -n ecommerce-poc
kubectl get svc -n monitoring

# Check Fargate profiles
aws eks list-fargate-profiles --cluster-name ecommerce-poc-eks --region ap-southeast-1

# Check ECR images
aws ecr describe-images --repository-name ecommerce-nodejs-catalog --region ap-southeast-1

# Check CloudWatch logs
aws logs tail /aws/eks/ecommerce-poc-eks/application --follow --region ap-southeast-1
```

## Next Steps for Production

1. **Add Ingress Controller** (AWS ALB Controller)
2. **Configure TLS** (ACM + ALB)
3. **Set up HPA** (Horizontal Pod Autoscaler)
4. **Add Persistent Storage** (EBS CSI Driver + PVCs)
5. **Implement CI/CD** (AWS CodePipeline or GitHub Actions)
6. **Add Secrets Management** (AWS Secrets Manager + External Secrets Operator)
7. **Configure Network Policies**
8. **Set up Multi-Environment** (dev/staging/prod)
9. **Add Backup Strategy** (Velero)
10. **Implement Alerting** (Prometheus Alertmanager + SNS)

## Files Updated

- ✅ `README.md` - Complete deployment guide
- ✅ `k8s/README.md` - Kubernetes manifests documentation
- ✅ `k8s/kustomization.yaml` - Added kube-state-metrics and traffic-generator
- ✅ `k8s/prometheus/kube-state-metrics.yaml` - New file
- ✅ `k8s/prometheus/prometheus-deployment.yaml` - Updated with kube-state-metrics scrape config
- ✅ `k8s/traffic-generator.yaml` - New file
- ✅ `k8s/load-test.sh` - New file
- ✅ `k8s/grafana/import-dashboards.sh` - New file
- ✅ `DEPLOYMENT_SUMMARY.md` - This file

## Verification Checklist

- [x] All 7 pods running (4 in ecommerce-poc, 3 in monitoring)
- [x] Prometheus scraping all targets
- [x] Grafana accessible with dashboards
- [x] All services responding to health checks
- [x] Metrics being collected
- [x] CloudWatch Logs receiving logs
- [x] Load testing working
- [x] All files committed to repository
