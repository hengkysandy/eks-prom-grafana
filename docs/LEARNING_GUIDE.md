# 🎓 Junior DevOps Learning Guide

Welcome! This guide will teach you production-ready Kubernetes and AWS EKS concepts through hands-on practice.

## Table of Contents

1. [Learning Path](#learning-path)
2. [Core Concepts](#core-concepts)
3. [Hands-On Labs](#hands-on-labs)
4. [Troubleshooting Guide](#troubleshooting-guide)
5. [Best Practices](#best-practices)
6. [Certification Prep](#certification-prep)

---

## Learning Path

### Week 1: Foundations
- [ ] Understand Docker containers
- [ ] Learn Kubernetes basics (Pods, Deployments, Services)
- [ ] Set up local development environment
- [ ] Deploy this project to EKS

### Week 2: Infrastructure as Code
- [ ] Learn Terraform basics
- [ ] Understand AWS networking (VPC, Subnets, NAT)
- [ ] Study EKS architecture
- [ ] Modify and apply Terraform changes

### Week 3: Observability
- [ ] Understand metrics, logs, and traces
- [ ] Configure Prometheus scraping
- [ ] Create Grafana dashboards
- [ ] Set up alerting rules

### Week 4: Production Operations
- [ ] Implement auto-scaling
- [ ] Practice incident response
- [ ] Optimize costs
- [ ] Document runbooks

---

## Core Concepts

### 1. Kubernetes Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     KUBERNETES CLUSTER                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  CONTROL PLANE (Managed by AWS EKS)                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  API Server  │ │   etcd       │ │  Scheduler   │        │
│  │  (kubectl)   │ │  (state)     │ │  (placement) │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                              │
│  WORKER NODES (EC2 Instances)                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Node 1 (t3.medium)                                 │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐              │    │
│  │  │  Pod A  │ │  Pod B  │ │  Pod C  │              │    │
│  │  │ (nginx) │ │ (app)   │ │ (redis) │              │    │
│  │  └─────────┘ └─────────┘ └─────────┘              │    │
│  │                                                     │    │
│  │  kubelet | kube-proxy | container runtime          │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Key Components:**
- **Pod**: Smallest deployable unit, contains one or more containers
- **Deployment**: Manages Pod replicas and rolling updates
- **Service**: Stable network endpoint for Pods
- **ConfigMap/Secret**: Configuration and sensitive data
- **PersistentVolumeClaim**: Storage request

### 2. Observability Pillars

```
┌─────────────────────────────────────────────────────────────┐
│                    THREE PILLARS                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  METRICS (Prometheus)          LOGS (Loki)                  │
│  ┌─────────────────┐          ┌─────────────────┐          │
│  │ • CPU usage     │          │ • Application   │          │
│  │ • Memory        │          │   output        │          │
│  │ • Request count │          │ • Error msgs    │          │
│  │ • Latency       │          │ • Debug info    │          │
│  └─────────────────┘          └─────────────────┘          │
│                                                              │
│  TRACES (Tempo)                                             │
│  ┌─────────────────────────────────────────────┐           │
│  │ Request flow across services:                │           │
│  │ User → Catalog → Orders → Inventory         │           │
│  │ [50ms]   [30ms]    [20ms]                   │           │
│  └─────────────────────────────────────────────┘           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**When to use each:**
- **Metrics**: "How many requests per second?" "What's the error rate?"
- **Logs**: "Why did this specific request fail?"
- **Traces**: "Where is the latency coming from in this request?"

### 3. Infrastructure as Code (Terraform)

```hcl
# Example: Creating an EKS cluster
resource "aws_eks_cluster" "main" {
  name     = "my-cluster"
  role_arn = aws_iam_role.eks.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = aws_subnet.private[*].id
  }
}

# Terraform Workflow:
# 1. terraform init    → Download providers
# 2. terraform plan    → Preview changes
# 3. terraform apply   → Create resources
# 4. terraform destroy → Delete resources
```

**Why IaC?**
- Version control your infrastructure
- Reproducible environments
- Code review for infrastructure changes
- Disaster recovery

---

## Hands-On Labs

### Lab 1: Deploy Your First Application

**Objective**: Deploy a simple web application to Kubernetes

```bash
# Step 1: Create a deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
  namespace: ecommerce-poc
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

# Step 2: Expose it with a Service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: hello-world
  namespace: ecommerce-poc
spec:
  selector:
    app: hello-world
  ports:
  - port: 80
    targetPort: 80
EOF

# Step 3: Test it
kubectl port-forward svc/hello-world -n ecommerce-poc 8080:80
# Open http://localhost:8080

# Step 4: Clean up
kubectl delete deployment hello-world -n ecommerce-poc
kubectl delete service hello-world -n ecommerce-poc
```

**What you learned:**
- Creating Deployments and Services
- Port forwarding for local access
- Resource cleanup

---

### Lab 2: Understand Prometheus Metrics

**Objective**: Learn how metrics are collected and queried

```bash
# Step 1: Access Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Step 2: Open http://localhost:9090 and try these queries:

# Query 1: Total HTTP requests
sum(http_requests_total)

# Query 2: Request rate per second (last 5 minutes)
rate(http_requests_total[5m])

# Query 3: 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Query 4: Error rate percentage
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100

# Query 5: Memory usage by pod
container_memory_usage_bytes{namespace="ecommerce-poc"}
```

**PromQL Basics:**
| Function | Purpose | Example |
|----------|---------|---------|
| `rate()` | Per-second rate of increase | `rate(requests[5m])` |
| `sum()` | Add values together | `sum(requests)` |
| `avg()` | Average value | `avg(cpu_usage)` |
| `histogram_quantile()` | Percentile calculation | `histogram_quantile(0.95, ...)` |

---

### Lab 3: Create a Grafana Dashboard

**Objective**: Build a custom dashboard from scratch

```bash
# Step 1: Access Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000
# Login: admin/admin

# Step 2: Create new dashboard
# Click: + → New Dashboard → Add visualization

# Step 3: Add these panels:

# Panel 1: Request Rate
# Query: sum(rate(http_requests_total{namespace="ecommerce-poc"}[5m])) by (service)
# Visualization: Time series

# Panel 2: Error Rate
# Query: sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service) * 100
# Visualization: Gauge (0-100%)

# Panel 3: Pod Memory
# Query: container_memory_usage_bytes{namespace="ecommerce-poc"} / 1024 / 1024
# Visualization: Time series
# Unit: megabytes

# Step 4: Save dashboard
# Click: Save icon → Name it "My First Dashboard"
```

---

### Lab 4: Trigger and Investigate an Alert

**Objective**: Understand the alerting workflow

```bash
# Step 1: Check current alerts
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/alerts

# Step 2: Trigger a service down alert
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=0

# Step 3: Watch the alert progress
# - PENDING (0-1 min): Condition met, waiting for 'for' duration
# - FIRING (after 1 min): Alert sent to Alertmanager

# Step 4: Check Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Open: http://localhost:9093

# Step 5: Restore the service
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=1

# Step 6: Watch alert resolve
# Alert will show as RESOLVED in Slack
```

**Alert States:**
```
INACTIVE → PENDING → FIRING → RESOLVED
              ↑         ↓
              └─────────┘
           (condition no longer met)
```

---

### Lab 5: Test Auto-Scaling

**Objective**: See Cluster Autoscaler in action

```bash
# Step 1: Check current nodes
kubectl get nodes

# Step 2: Check current pods
kubectl get pods -n ecommerce-poc

# Step 3: Scale up to trigger autoscaling
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=10

# Step 4: Watch pods go Pending (not enough resources)
kubectl get pods -n ecommerce-poc -w

# Step 5: Watch new node being added (~2 minutes)
kubectl get nodes -w

# Step 6: Check Cluster Autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=50

# Step 7: Scale back down
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=1

# Step 8: Watch node being removed (~10 minutes)
kubectl get nodes -w
```

**Autoscaler Decision Flow:**
```
Pod Pending → Check if schedulable → No → Scale up ASG → New node joins → Pod scheduled
```

---

### Lab 6: Distributed Tracing

**Objective**: Follow a request across multiple services

```bash
# Step 1: Generate cross-service traffic
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000

# Make requests that call multiple services
for i in {1..10}; do
  curl -s http://localhost:3000/api/products
  curl -s http://localhost:3000/api/orders
done

# Step 2: Access Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000

# Step 3: Go to Explore → Select Tempo data source

# Step 4: Search for traces
# - Service Name: nodejs-catalog
# - Click "Run query"

# Step 5: Click on a trace to see the full request flow
# You'll see: nodejs-catalog → python-orders → go-inventory
```

---

## Troubleshooting Guide

### Problem: Pods Stuck in Pending

```bash
# Step 1: Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Insufficient CPU/Memory → Scale up nodes or reduce requests
# - No matching nodes → Check node selectors/taints
# - PVC not bound → Check storage class

# Step 2: Check node resources
kubectl describe nodes | grep -A5 "Allocated resources"

# Step 3: Check if autoscaler is working
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=100 | grep -i scale
```

### Problem: No Metrics in Grafana

```bash
# Step 1: Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/targets
# All targets should be "UP"

# Step 2: Check if app exposes metrics
kubectl exec -n ecommerce-poc deployment/nodejs-catalog -- curl -s localhost:3000/metrics

# Step 3: Check Prometheus scrape config
kubectl get configmap prometheus-config -n monitoring -o yaml

# Step 4: Check Prometheus logs
kubectl logs -n monitoring deployment/prometheus --tail=50
```

### Problem: Alerts Not Firing

```bash
# Step 1: Check alert rules are loaded
kubectl port-forward -n monitoring svc/prometheus 9090:9090
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[].name'

# Step 2: Check alert condition manually
# Copy the alert expression and run it in Prometheus UI

# Step 3: Check Alertmanager is receiving alerts
kubectl logs -n monitoring deployment/alertmanager --tail=50

# Step 4: Check Slack webhook
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test alert"}' \
  YOUR_SLACK_WEBHOOK_URL
```

### Problem: High Memory Usage

```bash
# Step 1: Find memory-hungry pods
kubectl top pods -n ecommerce-poc --sort-by=memory

# Step 2: Check for memory leaks
kubectl logs <pod-name> -n ecommerce-poc --tail=100

# Step 3: Check resource limits
kubectl get deployment <name> -n ecommerce-poc -o yaml | grep -A10 resources

# Step 4: Increase limits if needed
kubectl patch deployment <name> -n ecommerce-poc --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "512Mi"}]'
```

---

## Best Practices

### 1. Resource Management

```yaml
# Always set resource requests and limits
resources:
  requests:
    memory: "128Mi"  # Guaranteed minimum
    cpu: "100m"      # 0.1 CPU core
  limits:
    memory: "256Mi"  # Maximum allowed
    cpu: "500m"      # 0.5 CPU core
```

**Why?**
- Requests: Used for scheduling decisions
- Limits: Prevents runaway containers

### 2. Health Checks

```yaml
# Always configure probes
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```

**Why?**
- Liveness: Restarts unhealthy containers
- Readiness: Removes from service until ready

### 3. Logging Standards

```javascript
// Good: Structured JSON logging
console.log(JSON.stringify({
  level: "info",
  message: "Order created",
  orderId: "12345",
  userId: "user-789",
  timestamp: new Date().toISOString()
}));

// Bad: Unstructured logging
console.log("Order 12345 created for user 789");
```

**Why?**
- Easier to search and filter
- Better for log aggregation (Loki)

### 4. Secret Management

```bash
# Good: Use Kubernetes Secrets
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=secret123

# Reference in deployment
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-creds
        key: password

# Bad: Hardcoded in code or ConfigMap
env:
  - name: DB_PASSWORD
    value: "secret123"  # Never do this!
```

### 5. Namespace Organization

```bash
# Separate concerns by namespace
kubectl get namespaces

# ecommerce-poc    - Application workloads
# monitoring       - Observability stack
# kube-system      - Kubernetes components
# kubernetes-dashboard - Dashboard UI
```

---

## Certification Prep

This project covers topics from:

### CKA (Certified Kubernetes Administrator)
- [x] Cluster architecture
- [x] Workloads & scheduling
- [x] Services & networking
- [x] Storage
- [x] Troubleshooting

### AWS Solutions Architect Associate
- [x] VPC networking
- [x] IAM roles and policies
- [x] EKS architecture
- [x] EBS storage
- [x] Auto Scaling

### Prometheus Certified Associate
- [x] PromQL queries
- [x] Alerting rules
- [x] Service discovery
- [x] Recording rules

---

## Next Steps

After completing this project:

1. **Add CI/CD Pipeline**: Set up GitHub Actions for automated deployments
2. **Implement GitOps**: Use ArgoCD or Flux for declarative deployments
3. **Add Service Mesh**: Implement Istio for advanced traffic management
4. **Multi-Environment**: Create dev/staging/prod environments
5. **Disaster Recovery**: Practice backup and restore procedures

---

## Resources

### Documentation
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)

### Practice
- [Kubernetes Playground](https://labs.play-with-k8s.com/)
- [Katacoda Scenarios](https://www.katacoda.com/courses/kubernetes)
- [AWS Free Tier](https://aws.amazon.com/free/)

### Community
- [CNCF Slack](https://slack.cncf.io/)
- [r/kubernetes](https://reddit.com/r/kubernetes)
- [AWS re:Post](https://repost.aws/)

---

Happy Learning! 🚀
