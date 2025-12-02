# Getting Started from Scratch

This guide walks you through deploying the entire e-commerce microservices platform from zero to fully operational, with detailed explanations of how everything connects.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Understanding the Architecture](#understanding-the-architecture)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [How Monitoring Works](#how-monitoring-works)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
```bash
# Check AWS CLI
aws --version  # Need v2.x
aws sts get-caller-identity  # Verify credentials

# Check Docker
docker --version
docker ps  # Verify Docker is running

# Check kubectl
kubectl version --client

# Check Terraform
terraform version  # Need >= 1.0

# Check jq (for dashboard imports)
jq --version
```

### AWS Configuration
```bash
# Set region
aws configure set region ap-southeast-1

# Verify
aws configure get region
```

### Required Permissions
See `IAM_permissions.md` for detailed IAM requirements.

---

## Understanding the Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    EKS Cluster                         │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │         ecommerce-poc namespace              │    │  │
│  │  │                                              │    │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │    │  │
│  │  │  │ Node.js  │  │  Python  │  │    Go    │  │    │  │
│  │  │  │ Catalog  │  │  Orders  │  │Inventory │  │    │  │
│  │  │  │ :3000    │  │  :5000   │  │  :8080   │  │    │  │
│  │  │  │/metrics  │  │ /metrics │  │ /metrics │  │    │  │
│  │  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  │    │  │
│  │  │       │             │             │         │    │  │
│  │  └───────┼─────────────┼─────────────┼─────────┘    │  │
│  │          │             │             │              │  │
│  │          │ Scrapes every 15s         │              │  │
│  │          └─────────────┼─────────────┘              │  │
│  │                        ▼                            │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │         monitoring namespace                 │  │  │
│  │  │                                              │  │  │
│  │  │  ┌────────────────┐    ┌─────────────────┐  │  │  │
│  │  │  │  Prometheus    │◄───│kube-state-metrics│ │  │  │
│  │  │  │  :9090         │    │  :8080          │  │  │  │
│  │  │  │  (Storage)     │    │  (K8s metrics)  │  │  │  │
│  │  │  └───────┬────────┘    └─────────────────┘  │  │  │
│  │  │          │                                   │  │  │
│  │  │          │ Queries via PromQL                │  │  │
│  │  │          ▼                                   │  │  │
│  │  │  ┌────────────────┐                         │  │  │
│  │  │  │    Grafana     │                         │  │  │
│  │  │  │    :3000       │                         │  │  │
│  │  │  │  (Dashboards)  │                         │  │  │
│  │  │  └────────────────┘                         │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │              CloudWatch Logs                      │  │
│  │  /aws/eks/ecommerce-poc-eks/application          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### How Applications Connect to Prometheus

**1. Applications Expose Metrics**

Each microservice includes a Prometheus client library:
- **Node.js**: `prom-client` package
- **Python**: `prometheus-client` package  
- **Go**: `prometheus/client_golang` package

These libraries expose a `/metrics` endpoint in Prometheus format:
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",route="/products",status="200"} 42
```

**2. Prometheus Discovers and Scrapes**

Prometheus configuration (`k8s/prometheus/prometheus-deployment.yaml`):
```yaml
scrape_configs:
  - job_name: 'nodejs-catalog'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: [ecommerce-poc]
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: nodejs-catalog
      - source_labels: [__meta_kubernetes_pod_ip]
        target_label: __address__
        replacement: $1:3000
```

This means:
- Prometheus watches Kubernetes API for pods
- Filters pods with label `app=nodejs-catalog`
- Scrapes `http://<pod-ip>:3000/metrics` every 15 seconds
- Stores time-series data in memory

**3. Grafana Queries Prometheus**

Grafana is pre-configured with Prometheus datasource:
```yaml
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus.monitoring.svc.cluster.local:9090
    isDefault: true
```

Dashboards use PromQL queries:
```promql
# Request rate per service
rate(http_requests_total[5m])

# Total requests
sum(http_requests_total) by (service)
```

---

## Step-by-Step Deployment

### Phase 1: Infrastructure Setup (15 minutes)

**Step 1.1: Clone/Navigate to Project**
```bash
cd /path/to/poc-kiro
```

**Step 1.2: Review Checklist**
```bash
cat CHECKLIST_BEFORE_APPLY.md
```

**Step 1.3: Initialize Terraform**
```bash
cd terraform
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

**Step 1.4: Plan Infrastructure**
```bash
terraform plan
```

Review the plan. You should see:
- 1 EKS cluster
- 4 Fargate profiles
- 3 ECR repositories
- 1 NAT Gateway
- 1 CloudWatch log group
- Multiple IAM roles and policies

**Step 1.5: Apply Infrastructure**
```bash
terraform apply
```

Type `yes` when prompted.

⏱️ **Wait 10-15 minutes** for EKS cluster creation.

**Step 1.6: Save Outputs**
```bash
terraform output > ../terraform-outputs.txt
cat ../terraform-outputs.txt
```

You should see:
- `cluster_name`
- `ecr_repository_urls`
- `cloudwatch_log_group_name`

---

### Phase 2: Build and Push Images (5 minutes)

**Step 2.1: Authenticate with ECR**
```bash
cd ../apps
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin \
  683031685817.dkr.ecr.ap-southeast-1.amazonaws.com
```

Expected: `Login Succeeded`

**Step 2.2: Build and Push All Images**
```bash
./build-and-push.sh
```

This script:
1. Builds Node.js image → Pushes to ECR
2. Builds Python image → Pushes to ECR
3. Builds Go image → Pushes to ECR

⏱️ **Wait 3-5 minutes** for builds.

**Step 2.3: Verify Images**
```bash
aws ecr describe-images --repository-name ecommerce-nodejs-catalog --region ap-southeast-1
aws ecr describe-images --repository-name ecommerce-python-orders --region ap-southeast-1
aws ecr describe-images --repository-name ecommerce-go-inventory --region ap-southeast-1
```

Each should show at least one image with tag `latest`.

---

### Phase 3: Configure kubectl (1 minute)

**Step 3.1: Update kubeconfig**
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name ecommerce-poc-eks
```

Expected: `Added new context...`

**Step 3.2: Verify Connection**
```bash
kubectl get nodes
```

Note: Fargate doesn't show nodes. This is normal.

```bash
kubectl get pods -n kube-system
```

You should see CoreDNS pods running.

---

### Phase 4: Deploy Applications (5 minutes)

**Step 4.1: Deploy Everything**
```bash
cd ../k8s
kubectl apply -k .
```

This deploys:
- 3 namespaces (ecommerce-poc, monitoring, aws-observability)
- 3 microservices (nodejs, python, go)
- 1 traffic generator
- Prometheus + kube-state-metrics
- Grafana
- Fargate logging config

**Step 4.2: Watch Pods Starting**

Open 2 terminals:

Terminal 1:
```bash
kubectl get pods -n ecommerce-poc -w
```

Terminal 2:
```bash
kubectl get pods -n monitoring -w
```

⏱️ **Wait 2-3 minutes** for Fargate to provision pods.

Expected final state:
```
# ecommerce-poc namespace
nodejs-catalog-xxx    1/1  Running
python-orders-xxx     1/1  Running
go-inventory-xxx      1/1  Running
traffic-generator     1/1  Running

# monitoring namespace
prometheus-xxx        1/1  Running
grafana-xxx           1/1  Running
kube-state-metrics-xxx 1/1 Running
```

---

### Phase 5: Verify Services (5 minutes)

**Step 5.1: Test Node.js Service**

Terminal 1:
```bash
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000
```

Terminal 2:
```bash
curl http://localhost:3000/health
# Expected: {"status":"healthy"}

curl http://localhost:3000/products
# Expected: JSON array of products

curl http://localhost:3000/metrics
# Expected: Prometheus metrics
```

**Step 5.2: Test Python Service**

Terminal 1:
```bash
kubectl port-forward -n ecommerce-poc svc/python-orders 5000:5000
```

Terminal 2:
```bash
curl http://localhost:5000/health
curl http://localhost:5000/orders
curl http://localhost:5000/metrics
```

**Step 5.3: Test Go Service**

Terminal 1:
```bash
kubectl port-forward -n ecommerce-poc svc/go-inventory 8080:8080
```

Terminal 2:
```bash
curl http://localhost:8080/health
curl http://localhost:8080/inventory
curl http://localhost:8080/metrics
```

---

### Phase 6: Access Monitoring (5 minutes)

**Step 6.1: Port-Forward Prometheus**

Terminal 1:
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Terminal 2:
```bash
# Open browser
open http://localhost:9090

# Or check targets via CLI
curl http://localhost:9090/api/v1/targets | jq .
```

You should see 4 targets:
- nodejs-catalog
- python-orders
- go-inventory
- kube-state-metrics

All should be `UP`.

**Step 6.2: Port-Forward Grafana**

Terminal 1:
```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

Terminal 2:
```bash
# Open browser
open http://localhost:3001
```

Login:
- Username: `admin`
- Password: `admin`

**Step 6.3: Import Dashboards**

Terminal 1 (keep Grafana port-forward running)

Terminal 2:
```bash
cd k8s/grafana
./import-dashboards.sh
```

This imports 3 Kubernetes dashboards.

**Step 6.4: Verify Dashboards**

In Grafana:
1. Click **Dashboards** (four squares icon)
2. You should see:
   - Kubernetes Cluster Monitoring via Prometheus
   - Kubernetes Deployment Statefulset Daemonset metrics
   - Kubernetes Views Pods

3. Open any dashboard
4. You should see metrics and graphs

---

### Phase 7: Generate Load and View Metrics (2 minutes)

**Step 7.1: Run Load Test**
```bash
cd k8s
./load-test.sh 30
```

This sends 90 requests (30 per service) over 30 seconds.

**Step 7.2: View Metrics in Grafana**

While load test is running:
1. Open Grafana: http://localhost:3001
2. Go to **Explore**
3. Try these queries:

```promql
# Request rate
rate(http_requests_total[1m])

# Total requests by service
sum(http_requests_total) by (service)

# Pod CPU usage
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)
```

You should see graphs showing the traffic spike.

---

## How Monitoring Works

### Metrics Collection Flow

**1. Application Startup**
```
App starts → Prometheus client library initializes → /metrics endpoint available
```

**2. Prometheus Discovery**
```
Prometheus → Queries Kubernetes API → Finds pods with matching labels → Adds to scrape targets
```

**3. Scraping**
```
Every 15 seconds:
  Prometheus → HTTP GET http://<pod-ip>:<port>/metrics → Parses metrics → Stores in TSDB
```

**4. Grafana Queries**
```
User opens dashboard → Grafana sends PromQL query → Prometheus returns data → Grafana renders graph
```

### Example: Tracking a Single Request

1. **User makes request**
   ```bash
   curl http://localhost:3000/products
   ```

2. **App increments counter**
   ```javascript
   // In Node.js app
   httpRequestsTotal.inc({ method: 'GET', route: '/products', status: 200 })
   ```

3. **Prometheus scrapes (within 15 seconds)**
   ```
   GET http://10.0.1.42:3000/metrics
   Response: http_requests_total{method="GET",route="/products",status="200"} 43
   ```

4. **Grafana queries**
   ```promql
   rate(http_requests_total[5m])
   ```

5. **User sees graph** showing requests per second

### Kubernetes Metrics

**kube-state-metrics** watches Kubernetes API:
```
K8s API → kube-state-metrics → Exposes metrics → Prometheus scrapes → Grafana displays
```

Example metrics:
- `kube_pod_info` - Pod metadata
- `kube_deployment_status_replicas` - Replica counts
- `kube_pod_container_resource_requests` - Resource requests

---

## Verification

### Complete System Check

```bash
# 1. Check all pods running
kubectl get pods -n ecommerce-poc
kubectl get pods -n monitoring
# Expected: All 7 pods in Running state

# 2. Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
# Expected: All targets "up"

# 3. Check Grafana datasource
kubectl port-forward -n monitoring svc/grafana 3001:3000 &
curl -s -u admin:admin http://localhost:3001/api/datasources | jq '.[0] | {name, type, url}'
# Expected: Prometheus datasource configured

# 4. Test metrics collection
curl -s http://localhost:9090/api/v1/query?query=up | jq '.data.result[] | {job: .metric.job, value: .value[1]}'
# Expected: All jobs showing "1" (up)

# 5. Check CloudWatch logs
aws logs tail /aws/eks/ecommerce-poc-eks/application --since 5m --region ap-southeast-1
# Expected: Recent log entries from all services
```

---

## Troubleshooting

### Pods Stuck in Pending

**Symptom:** Pods show `Pending` status for > 2 minutes

**Check:**
```bash
kubectl describe pod <pod-name> -n <namespace>
```

**Common causes:**
1. Fargate profile doesn't match namespace
2. No available subnets
3. Image pull errors

**Fix:**
```bash
# Check Fargate profiles
aws eks list-fargate-profiles --cluster-name ecommerce-poc-eks --region ap-southeast-1

# Verify profile selectors
aws eks describe-fargate-profile \
  --cluster-name ecommerce-poc-eks \
  --fargate-profile-name ecommerce-app-profile \
  --region ap-southeast-1
```

### Prometheus Not Scraping

**Symptom:** Targets show as "down" in Prometheus

**Check:**
```bash
kubectl logs -n monitoring deployment/prometheus
kubectl get pods -n ecommerce-poc --show-labels
```

**Common causes:**
1. Pod labels don't match scrape config
2. Wrong port in scrape config
3. Network policy blocking traffic

**Fix:**
```bash
# Verify labels match
kubectl get pods -n ecommerce-poc -l app=nodejs-catalog

# Test connectivity from Prometheus pod
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- http://nodejs-catalog.ecommerce-poc.svc.cluster.local:3000/metrics
```

### Grafana Shows No Data

**Symptom:** Dashboards are empty

**Check:**
```bash
# 1. Verify Prometheus is working
kubectl port-forward -n monitoring svc/prometheus 9090:9090
curl http://localhost:9090/api/v1/query?query=up

# 2. Check Grafana datasource
kubectl port-forward -n monitoring svc/grafana 3001:3000
curl -u admin:admin http://localhost:3001/api/datasources

# 3. Check if kube-state-metrics is running
kubectl get pods -n monitoring | grep kube-state-metrics
```

**Fix:**
```bash
# Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring

# Re-import dashboards
cd k8s/grafana
./import-dashboards.sh
```

---

## Next Steps

Now that everything is running:

1. **Explore Grafana Dashboards** - See real-time metrics
2. **Run Load Tests** - Generate traffic and observe behavior
3. **Check CloudWatch Logs** - View application logs
4. **Scale Services** - Test horizontal scaling
5. **Customize Dashboards** - Create your own visualizations

For production deployment, see `README.md` section "Next Steps for Production".

---

## Summary

You've successfully deployed:
- ✅ EKS cluster with Fargate
- ✅ 3 microservices with metrics
- ✅ Prometheus collecting metrics
- ✅ kube-state-metrics for K8s metrics
- ✅ Grafana with dashboards
- ✅ CloudWatch Logs integration
- ✅ Load testing capability

**Total deployment time:** ~30-40 minutes

**Monthly cost:** ~$165-180

**Access points:**
- Grafana: http://localhost:3001 (admin/admin)
- Prometheus: http://localhost:9090
- Services: Port-forward as needed
