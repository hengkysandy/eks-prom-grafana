# Production-Ready Monitoring Stack

## Overview

This document describes the comprehensive monitoring setup for the EKS cluster with full observability including metrics, logs, traces, and alerting.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MONITORING STACK                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │ Node Exporter│    │ kube-state   │    │   cAdvisor   │                  │
│  │  (DaemonSet) │    │   metrics    │    │  (built-in)  │                  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                  │
│         │                   │                   │                           │
│         └───────────────────┼───────────────────┘                           │
│                             ↓                                               │
│                    ┌────────────────┐                                       │
│                    │   Prometheus   │──────→ Alert Rules                    │
│                    │    (30GB)      │              │                        │
│                    └────────┬───────┘              ↓                        │
│                             │            ┌────────────────┐                 │
│                             │            │  Alertmanager  │──→ Slack       │
│                             │            └────────────────┘                 │
│                             ↓                                               │
│  ┌──────────────┐  ┌────────────────┐  ┌──────────────┐                    │
│  │    Loki      │  │    Grafana     │  │    Tempo     │                    │
│  │   (10GB)     │  │    (10GB)      │  │   (10GB)     │                    │
│  └──────┬───────┘  └────────────────┘  └──────┬───────┘                    │
│         ↑                                      ↑                            │
│         │                                      │                            │
│  ┌──────┴───────┐                    ┌────────┴───────┐                    │
│  │   Promtail   │                    │  OpenTelemetry │                    │
│  │  (DaemonSet) │                    │     (OTLP)     │                    │
│  └──────────────┘                    └────────────────┘                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

### Metrics Collection

| Component | Purpose | Storage |
|-----------|---------|---------|
| Prometheus | Time-series metrics database | 30GB PVC, 15 days retention |
| Node Exporter | Node-level metrics (CPU, memory, disk) | DaemonSet on each node |
| kube-state-metrics | Kubernetes object metrics | Deployment |
| cAdvisor | Container metrics | Built into kubelet |

### Log Collection

| Component | Purpose | Storage |
|-----------|---------|---------|
| Loki | Log aggregation and querying | 10GB PVC, 7 days retention |
| Promtail | Log collection from pods | DaemonSet on each node |

### Trace Collection

| Component | Purpose | Storage |
|-----------|---------|---------|
| Tempo | Distributed tracing backend | 10GB PVC, 7 days retention |
| OpenTelemetry | Instrumentation in apps | SDK in each service |

### Alerting

| Component | Purpose |
|-----------|---------|
| Alertmanager | Alert routing and notification |
| Slack Integration | Alert delivery to Slack channel |

## Grafana Dashboards

### 1. Kubernetes Cluster Overview
**UID:** `k8s-cluster-overview`

Metrics displayed:
- Nodes Ready count
- Total Running Pods
- Pending/Failed Pods
- Container Restarts (1h)
- Active Alerts count
- Node CPU Usage %
- Node Memory Usage %
- CPU/Memory Requests vs Capacity (gauge)
- Node Disk Usage %
- PVC Usage table
- PVC Used % (bar gauge)
- PVC Free Space

### 2. Pod & Container Metrics
**UID:** `pod-metrics`

Metrics displayed:
- Pod Status table
- Pod CPU Usage
- Pod Memory Usage
- CPU/Memory Usage vs Requests
- Network I/O (RX/TX)
- Container Restarts
- Request Rate by Pod
- Error Rate by Pod

### 3. Application Performance & HTTP Metrics
**UID:** `app-performance`

Metrics displayed:
- Success Rate (2xx) %
- Error Rate %
- Total Requests (1h)
- Total Errors (1h)
- P95 Latency
- Request Rate (req/s)
- 2XX/4XX/5XX rates over time
- HTTP Status Distribution (pie chart)
- Errors by Type (pie chart)
- Errors by Service (bar gauge)
- P50/P95/P99 Latency
- P98 by HTTP Method (GET, POST, PUT)
- Slowest Endpoints table (P98)
- Service CPU/Memory Usage

### 4. Application Logs & Traces
**UID:** `logs-traces`

Features:
- Log Volume over time
- Error Log Volume
- Errors by Container (1h)
- All Application Logs panel
- Error & Exception Logs panel
- Recent Traces panel
- Trace Search by Service

### 5. Kubernetes Components Health
**UID:** `k8s-health`

Metrics displayed:
- Node Status
- Deployment Health %
- DaemonSet Health %
- Prometheus/Alertmanager/Grafana status
- Application Services status (nodejs, python, go)
- Deployment Status table
- Pod Status by Namespace
- CPU/Memory Allocatable vs Requested
- Active Alerts table

### 6. Microservices Observability
**UID:** (existing dashboard)

Combined view of metrics, logs, and traces.

## Alert Rules

### Infrastructure Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| NodeHighCPU | CPU > 80% for 5m | warning |
| NodeHighMemory | Memory > 85% for 5m | warning |
| NodeDiskSpaceLow | Disk > 85% for 5m | warning |
| NodeDiskSpaceCritical | Disk > 95% for 2m | critical |
| NodeNotReady | Node not ready for 5m | critical |
| PodCrashLooping | >3 restarts in 15m | critical |
| PodNotReady | Not ready for 10m | warning |
| PodHighCPU | >150% of requested CPU | warning |
| PodHighMemory | >150% of requested memory | warning |
| PodOOMKilled | Container OOMKilled | critical |
| DeploymentReplicasMismatch | Replicas mismatch for 10m | warning |
| PVCAlmostFull | PVC > 85% full | warning |

### Application Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| HighErrorRate | Error rate > 5% for 5m | warning |
| CriticalErrorRate | Error rate > 10% for 2m | critical |
| HighResponseTime | P95 > 2s for 5m | warning |
| ServiceDown | Service unreachable for 1m | critical |
| NoRequests | No requests for 10m | warning |
| High5xxRate | 5xx rate > 1% for 5m | warning |
| High4xxRate | 4xx rate > 20% for 5m | warning |

### Monitoring Stack Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| PrometheusDown | Prometheus unreachable | critical |
| PrometheusStorageAlmostFull | Storage > 80% | warning |
| AlertmanagerDown | Alertmanager unreachable | critical |
| GrafanaDown | Grafana unreachable | critical |

## Slack Integration

Alerts are sent to Slack with the following configuration:

- **Channel:** #alerts
- **Grouping:** By alertname, severity, namespace
- **Group Wait:** 30 seconds
- **Group Interval:** 5 minutes
- **Repeat Interval:** 4 hours (1 hour for critical)

### Alert Format

```
🔥 FIRING [CRITICAL]
Alert: High error rate in nodejs-catalog
Description: Error rate is 15.2% (threshold: 10%)
Severity: critical
Namespace: ecommerce-poc
Pod: nodejs-catalog-xxx
Started: 2025-12-09 12:00:00
```

## Access URLs

```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000
# Open: http://localhost:3001 (admin/admin)

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090

# Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Open: http://localhost:9093
```

## Useful PromQL Queries

### Node Metrics
```promql
# CPU Usage %
100 - (avg by(node) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage %
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk Usage %
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
```

### Application Metrics
```promql
# Request Rate
sum(rate(http_requests_total[5m])) by (job)

# Error Rate %
sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m])) * 100

# P95 Latency
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Success Rate %
sum(rate(http_requests_total{status_code=~"2.."}[5m])) / sum(rate(http_requests_total[5m])) * 100
```

### Kubernetes Metrics
```promql
# Running Pods
sum(kube_pod_status_phase{phase="Running"})

# Container Restarts
sum(increase(kube_pod_container_status_restarts_total[1h]))

# PVC Usage %
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100
```

## Loki LogQL Queries

```logql
# All application logs
{namespace="ecommerce-poc"}

# Logs by container
{container="nodejs-catalog"}
{container="python-orders"}
{container="go-inventory"}

# Error logs
{namespace="ecommerce-poc"} |~ "(?i)error|exception|fail"

# JSON parsing
{namespace="ecommerce-poc"} | json | level="error"
```

## Tempo TraceQL Queries

```traceql
# All traces from a service
{ service.name="nodejs-catalog" }

# Error traces
{ status=error }

# Slow traces (>1s)
{ duration > 1s }

# Traces with specific HTTP status
{ span.http.status_code >= 500 }
```

## File Structure

```
k8s/
├── prometheus/
│   ├── prometheus-deployment.yaml  # Prometheus with rules
│   ├── kube-state-metrics.yaml     # K8s object metrics
│   ├── node-exporter.yaml          # Node metrics DaemonSet
│   ├── alertmanager.yaml           # Alertmanager + Slack
│   └── alert-rules.yaml            # Alert rule definitions
├── grafana/
│   ├── grafana-deployment.yaml     # Grafana with datasources
│   └── dashboards/
│       ├── kubernetes-cluster-overview.json
│       ├── pod-metrics.json
│       ├── application-performance.json
│       ├── logs-traces.json
│       └── kubernetes-health.json
├── loki/
│   ├── loki-deployment.yaml
│   └── promtail-daemonset.yaml
├── tempo/
│   └── tempo-deployment.yaml
└── kustomization.yaml
```

## Cost Estimate

| Component | Resource | Monthly Cost |
|-----------|----------|-------------|
| Prometheus | 30GB EBS | ~$3 |
| Grafana | 10GB EBS | ~$1 |
| Loki | 10GB EBS | ~$1 |
| Tempo | 10GB EBS | ~$1 |
| **Total Storage** | 60GB | **~$6** |

Note: Compute costs are included in the EC2 node pricing (~$60/month for 2x t3.medium).

## Maintenance

### Scaling Prometheus Storage
```bash
# Edit PVC (requires volume expansion enabled)
kubectl patch pvc prometheus-data -n monitoring -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

### Viewing Alert Status
```bash
# Check firing alerts
kubectl port-forward -n monitoring svc/prometheus 9090:9090
curl http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing")'
```

### Reloading Prometheus Config
```bash
kubectl exec -n monitoring deployment/prometheus -- kill -HUP 1
```
