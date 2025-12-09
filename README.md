# E-Commerce Microservices PoC on AWS EKS (v4)

A production-ready proof-of-concept for deploying microservices to AWS EKS with comprehensive observability, auto-scaling, and alerting.

## 🎯 What You'll Learn

This project teaches junior DevOps engineers:
- Kubernetes deployment on AWS EKS
- Infrastructure as Code with Terraform
- Container orchestration and scaling
- Full observability stack (metrics, logs, traces)
- Production alerting with Slack integration
- SLA monitoring and reporting

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Infrastructure Components](#infrastructure-components)
5. [Observability Stack](#observability-stack)
6. [Alerting System](#alerting-system)
7. [Auto-Scaling](#auto-scaling)
8. [Dashboards](#dashboards)
9. [Testing](#testing)
10. [Cost Estimate](#cost-estimate)
11. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS EKS CLUSTER                                │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    EC2 Node Group (t3.medium)                        │   │
│  │                    Auto-scaling: 1-3 nodes                           │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │              Application Namespace (ecommerce-poc)            │   │   │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐              │   │   │
│  │  │  │  Node.js   │  │   Python   │  │     Go     │              │   │   │
│  │  │  │  Catalog   │──│   Orders   │──│  Inventory │              │   │   │
│  │  │  │  :3000     │  │   :5000    │  │   :8080    │              │   │   │
│  │  │  └────────────┘  └────────────┘  └────────────┘              │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │              Monitoring Namespace (monitoring)                │   │   │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐              │   │   │
│  │  │  │ Prometheus │  │   Loki     │  │   Tempo    │              │   │   │
│  │  │  │  (30GB)    │  │  (10GB)    │  │  (10GB)    │              │   │   │
│  │  │  └────────────┘  └────────────┘  └────────────┘              │   │   │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐              │   │   │
│  │  │  │  Grafana   │  │Alertmanager│  │  Promtail  │              │   │   │
│  │  │  │  (10GB)    │  │            │  │ (DaemonSet)│              │   │   │
│  │  │  └────────────┘  └────────────┘  └────────────┘              │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │  EBS Volumes    │  │  Cluster        │  │  Node Exporter  │            │
│  │  (gp3, 60GB)    │  │  Autoscaler     │  │  (DaemonSet)    │            │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘            │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                         ┌─────────────────┐
                         │     Slack       │
                         │    Alerts       │
                         └─────────────────┘
```

---

## Prerequisites

### Required Tools
```bash
# Check versions
aws --version      # AWS CLI v2.x
kubectl version    # v1.28+
terraform version  # v1.0+
docker --version   # Docker Desktop
helm version       # v3.x
```

### AWS Configuration
```bash
# Configure AWS credentials
aws configure
# Region: ap-southeast-1
```

---

## Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd poc-kiro
git checkout v4
```

### 2. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

### 3. Configure kubectl
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name ecommerce-poc-eks
kubectl get nodes  # Verify connection
```

### 4. Build and Push Images
```bash
cd apps
./build-and-push.sh
```

### 5. Deploy Kubernetes Resources
```bash
cd k8s
kubectl apply -k .
```

### 6. Access Dashboards
```bash
# Grafana (Observability)
kubectl port-forward -n monitoring svc/grafana 3001:3000
# Open: http://localhost:3001 (admin/admin)

# Kubernetes Dashboard
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
# Open: https://localhost:8443
```

---

## Infrastructure Components

### Terraform Resources (`terraform/`)

| Resource | Description | File |
|----------|-------------|------|
| EKS Cluster | Kubernetes control plane | `main.tf` |
| EC2 Node Group | Worker nodes (t3.medium) | `main.tf` |
| VPC/Subnets | Private networking | `main.tf` |
| NAT Gateway | Outbound internet access | `main.tf` |
| ECR Repositories | Container registry | `main.tf` |
| EBS CSI Driver | Persistent volume support | `main.tf` |
| Cluster Autoscaler IAM | Auto-scaling permissions | `cluster-autoscaler.tf` |

### Key Configuration
```hcl
# Node Group Settings (variables.tf)
node_instance_types = ["t3.medium"]  # 2 vCPU, 4GB RAM
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3
```

---

## Observability Stack

### Components Overview

| Component | Purpose | Storage | Retention |
|-----------|---------|---------|-----------|
| **Prometheus** | Metrics collection | 30GB EBS | 15 days |
| **Loki** | Log aggregation | 10GB EBS | 7 days |
| **Tempo** | Distributed tracing | 10GB EBS | 7 days |
| **Grafana** | Visualization | 10GB EBS | N/A |
| **Alertmanager** | Alert routing | emptyDir | N/A |
| **Promtail** | Log collection | DaemonSet | N/A |
| **Node Exporter** | Node metrics | DaemonSet | N/A |

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA COLLECTION                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  METRICS:                                                       │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │ Application │───▶│ Prometheus  │───▶│  Grafana    │        │
│  │  /metrics   │    │  (scrape)   │    │ (visualize) │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
│                                                                 │
│  LOGS:                                                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │ Pod stdout  │───▶│  Promtail   │───▶│    Loki     │        │
│  │ /var/log    │    │ (DaemonSet) │    │  (storage)  │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
│                                                                 │
│  TRACES:                                                        │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │ Application │───▶│    OTLP     │───▶│   Tempo     │        │
│  │ OpenTelemetry│   │  (HTTP)     │    │  (storage)  │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Prometheus Scrape Targets

| Job Name | Target | Metrics |
|----------|--------|---------|
| `prometheus` | localhost:9090 | Self-monitoring |
| `alertmanager` | alertmanager:9093 | Alert metrics |
| `node-exporter` | *:9100 | Node CPU/Memory/Disk |
| `kubernetes-kubelet` | kubelet | Volume stats |
| `kubernetes-cadvisor` | cAdvisor | Container metrics |
| `kube-state-metrics` | kube-state-metrics:8080 | K8s object states |
| `nodejs-catalog` | nodejs-catalog:3000 | App metrics |
| `python-orders` | python-orders:5000 | App metrics |
| `go-inventory` | go-inventory:8080 | App metrics |

---

## Alerting System

### Alert Rules (`k8s/prometheus/alert-rules.yaml`)

#### Infrastructure Alerts
| Alert | Condition | Severity | For |
|-------|-----------|----------|-----|
| NodeHighCPU | CPU > 80% | warning | 5m |
| NodeHighMemory | Memory > 85% | warning | 5m |
| NodeDiskSpaceLow | Disk > 85% | warning | 5m |
| NodeDiskSpaceCritical | Disk > 95% | critical | 2m |
| NodeNotReady | Node not ready | critical | 5m |
| PodCrashLooping | >3 restarts/15m | critical | 5m |
| PodOOMKilled | OOMKilled | critical | 0m |
| PVCAlmostFull | PVC > 85% | warning | 5m |

#### Application Alerts
| Alert | Condition | Severity | For |
|-------|-----------|----------|-----|
| HighErrorRate | Error rate > 5% | warning | 5m |
| CriticalErrorRate | Error rate > 10% | critical | 2m |
| HighResponseTime | P95 > 2s | warning | 5m |
| ServiceDown | Service unreachable | critical | 1m |
| High5xxRate | 5xx rate > 1% | warning | 5m |
| High5xxErrorsIn5Min | >5 5xx errors in 5m | critical | 0m |

#### SLA Alerts
| Alert | Condition | Severity | For |
|-------|-----------|----------|-----|
| ServiceCompletelyDown | All pods down | critical | 1m |
| AllPodsDownNodejs | nodejs-catalog down | critical | 1m |
| AllPodsDownPython | python-orders down | critical | 1m |
| AllPodsDownGo | go-inventory down | critical | 1m |

### Slack Integration

Alerts are sent to Slack via webhook:
```yaml
# k8s/prometheus/alertmanager.yaml
global:
  slack_api_url: 'https://hooks.slack.com/services/...'

route:
  receiver: 'slack-notifications'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
```

---

## Auto-Scaling

### Cluster Autoscaler

Automatically adds/removes EC2 nodes based on pod demand.

**How it works:**
1. Pod is scheduled but can't fit on existing nodes
2. Pod enters `Pending` state
3. Cluster Autoscaler detects pending pods
4. New node is provisioned (~2 minutes)
5. Pod is scheduled on new node

**Configuration:**
```yaml
# k8s/cluster-autoscaler.yaml
- --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/ecommerce-poc-eks
- --balance-similar-node-groups
- --skip-nodes-with-system-pods=false
```

**Test Auto-scaling:**
```bash
# Scale to 10 pods (will trigger node scale-up)
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=10

# Watch nodes
kubectl get nodes -w

# Scale back down
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=1
```

---

## Dashboards

### Grafana Dashboards

| Dashboard | UID | Purpose |
|-----------|-----|---------|
| Kubernetes Cluster Overview | `k8s-cluster-overview` | Node metrics, PVC usage |
| Pod & Container Metrics | `pod-metrics` | Per-pod resources |
| Application Performance | `app-performance` | HTTP metrics, latency |
| Application Logs & Traces | `logs-traces` | Loki logs, Tempo traces |
| Kubernetes Components Health | `k8s-health` | Service status, alerts |
| SLA Report | `sla-report` | Uptime, availability |

### Access Dashboards
```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000
# URL: http://localhost:3001
# Login: admin/admin

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# URL: http://localhost:9090

# Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# URL: http://localhost:9093
```

### Kubernetes Dashboard
```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
# URL: https://localhost:8443

# Get login token
kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 --decode
```

---

## Testing

### Test Scripts (`k8s/tests/`)

| Script | Purpose | Duration |
|--------|---------|----------|
| `quick-test.sh` | Generate all metrics quickly | ~2 min |
| `run-all-tests.sh` | Full test suite | ~5 min |
| `test-http-traffic.sh` | 2XX, 4XX, 5XX responses | ~1 min |
| `test-errors.sh` | Error log generation | ~1 min |
| `test-latency.sh` | P95/P98/P99 latency | ~1 min |
| `test-cross-service.sh` | Distributed tracing | ~1 min |
| `test-alert-triggers.sh` | Trigger specific alerts | ~2 min |
| `test-pod-stress.sh` | CPU/Memory stress | ~2 min |
| `verify-data.sh` | Verify data collection | ~10 sec |

### Run Tests
```bash
cd k8s/tests

# Quick test (recommended for first run)
./quick-test.sh

# Full test suite
./run-all-tests.sh

# Verify all data is collected
./verify-data.sh
```

### Simulate Downtime
```bash
# Scale down service
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=0

# Wait for alert (1 minute)
sleep 90

# Check alerts
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing")'

# Restore service
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=1
```

---

## Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| EKS Control Plane | ~$73 |
| EC2 Nodes (2x t3.medium) | ~$60 |
| NAT Gateway | ~$32 |
| EBS Volumes (60GB gp3) | ~$6 |
| **Total** | **~$171/month** |

**With 3 nodes (auto-scaled):** ~$201/month

---

## Troubleshooting

### Common Issues

#### Pods Stuck in Pending
```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl describe nodes | grep -A5 "Allocated resources"

# Check if autoscaler is working
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=50
```

#### No Metrics in Grafana
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/targets

# Check if pods have metrics endpoint
kubectl exec -n ecommerce-poc deployment/nodejs-catalog -- curl -s localhost:3000/metrics
```

#### No Logs in Loki
```bash
# Check Promtail
kubectl logs -n monitoring -l app=promtail --tail=50

# Verify log labels
kubectl port-forward -n monitoring svc/loki 3100:3100
curl -s http://localhost:3100/loki/api/v1/label/container/values
```

#### Alerts Not Firing
```bash
# Check alert rules loaded
kubectl port-forward -n monitoring svc/prometheus 9090:9090
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[].name'

# Check Alertmanager
kubectl logs -n monitoring deployment/alertmanager --tail=50
```

### Useful Commands
```bash
# Get all resources
kubectl get all -A

# Check pod logs
kubectl logs -n <namespace> <pod-name> -f

# Execute into pod
kubectl exec -it -n <namespace> <pod-name> -- /bin/sh

# Check PVC usage
kubectl exec -n monitoring deployment/prometheus -- df -h /prometheus

# Restart deployment
kubectl rollout restart deployment/<name> -n <namespace>
```

---

## Project Structure

```
poc-kiro/
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # EKS, VPC, ECR, Node Group
│   ├── variables.tf             # Configuration variables
│   ├── outputs.tf               # Output values
│   └── cluster-autoscaler.tf    # Autoscaler IAM role
│
├── k8s/                         # Kubernetes manifests
│   ├── namespace.yaml           # Namespaces
│   ├── storage-class.yaml       # EBS gp3 StorageClass
│   ├── kustomization.yaml       # Kustomize config
│   │
│   ├── nodejs-deployment.yaml   # Node.js service
│   ├── python-deployment.yaml   # Python service
│   ├── go-deployment.yaml       # Go service
│   │
│   ├── prometheus/              # Prometheus stack
│   │   ├── prometheus-deployment.yaml
│   │   ├── kube-state-metrics.yaml
│   │   ├── node-exporter.yaml
│   │   ├── alertmanager.yaml
│   │   └── alert-rules.yaml
│   │
│   ├── grafana/                 # Grafana + Dashboards
│   │   ├── grafana-deployment.yaml
│   │   └── dashboards/
│   │       ├── kubernetes-cluster-overview.json
│   │       ├── pod-metrics.json
│   │       ├── application-performance.json
│   │       ├── logs-traces.json
│   │       ├── kubernetes-health.json
│   │       └── sla-report.json
│   │
│   ├── loki/                    # Loki + Promtail
│   │   ├── loki-deployment.yaml
│   │   └── promtail-daemonset.yaml
│   │
│   ├── tempo/                   # Tempo tracing
│   │   └── tempo-deployment.yaml
│   │
│   ├── cluster-autoscaler.yaml  # Cluster Autoscaler
│   │
│   └── tests/                   # Test scripts
│       ├── quick-test.sh
│       ├── run-all-tests.sh
│       ├── test-http-traffic.sh
│       ├── test-errors.sh
│       ├── test-latency.sh
│       ├── test-cross-service.sh
│       ├── test-alert-triggers.sh
│       ├── test-pod-stress.sh
│       └── verify-data.sh
│
├── apps/                        # Application source code
│   ├── nodejs/                  # Catalog service
│   │   ├── app.js
│   │   ├── tracing.js
│   │   ├── package.json
│   │   └── Dockerfile
│   │
│   ├── python/                  # Orders service
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   │
│   ├── go/                      # Inventory service
│   │   ├── main.go
│   │   ├── go.mod
│   │   └── Dockerfile
│   │
│   └── build-and-push.sh        # Build script
│
├── README.md                    # This file
├── MONITORING.md                # Monitoring documentation
├── TRACING_SUMMARY.md           # Tracing documentation
└── DOWNTIME_ALERT_TEST.md       # Alert testing results
```

---

## Cleanup

```bash
# Delete Kubernetes resources
cd k8s
kubectl delete -k .

# Delete Kubernetes Dashboard
helm uninstall kubernetes-dashboard -n kubernetes-dashboard

# Wait for PVCs to be deleted
kubectl get pvc -A

# Destroy Terraform infrastructure
cd ../terraform
terraform destroy -auto-approve
```

---

## Version History

| Version | Changes |
|---------|---------|
| v1 | Basic EKS with Fargate |
| v2 | Added observability (Prometheus, Grafana) |
| v3 | Migrated to EC2 nodes, added persistent storage |
| **v4** | Full production setup: Alerting, SLA, Auto-scaling, Kubernetes Dashboard |

---

## Contributing

1. Create a feature branch
2. Make changes
3. Test with `./k8s/tests/quick-test.sh`
4. Submit pull request

---

## License

MIT License - Feel free to use for learning and testing.
