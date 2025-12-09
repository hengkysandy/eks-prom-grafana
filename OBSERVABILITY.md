# Observability Guide

Guide to logs, metrics, and traces in the e-commerce microservices PoC.

## Overview

| Component | Purpose | Storage | Retention |
|-----------|---------|---------|-----------|
| Prometheus | Metrics | 30GB EBS | 15 days |
| Loki | Logs | 10GB EBS | 7 days |
| Tempo | Traces | 10GB EBS | 7 days |
| Grafana | Visualization | 10GB EBS | Persistent |

## Accessing Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

- URL: http://localhost:3001
- Username: `admin`
- Password: `admin`

## Datasources

Pre-configured in Grafana:

| Name | Type | URL |
|------|------|-----|
| Prometheus | prometheus | http://prometheus:9090 |
| Loki | loki | http://loki:3100 |
| Tempo | tempo | http://tempo:3200 |

## Viewing Metrics

### In Grafana Explore

1. Select **Prometheus** datasource
2. Enter PromQL query

### Common Queries

```promql
# Request rate by service
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status_code=~"5.."}[5m]) / rate(http_requests_total[5m])

# Response time p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Pod memory usage
container_memory_usage_bytes{namespace="ecommerce-poc"}

# Pod CPU usage
rate(container_cpu_usage_seconds_total{namespace="ecommerce-poc"}[5m])
```

## Viewing Logs

### In Grafana Explore

1. Select **Loki** datasource
2. Enter LogQL query

### Common Queries

```logql
# All logs from service
{app="nodejs-catalog"}

# Error logs
{app="nodejs-catalog"} |= "error"

# JSON parsing with filter
{app="nodejs-catalog"} | json | level="error"

# Logs with trace ID
{app="nodejs-catalog"} | json | trace_id != ""

# Rate of errors
count_over_time({app="nodejs-catalog"} |= "error" [5m])
```

## Viewing Traces

### In Grafana Explore

1. Select **Tempo** datasource
2. Search by:
   - Service Name
   - Tags (e.g., `http.status_code=500`)
   - Duration (e.g., `>100ms`)
   - Trace ID

### Trace Correlation

Logs include `trace_id` field. Click on trace_id in Loki to jump to Tempo.

## Prometheus Targets

Access Prometheus directly:

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Go to Status → Targets to see:
- nodejs-catalog
- python-orders
- go-inventory
- kube-state-metrics

## Persistent Storage

All monitoring components use EBS volumes:

```bash
# Check PVCs
kubectl get pvc -n monitoring

# Check PV details
kubectl describe pvc prometheus-data -n monitoring
```

## Troubleshooting

### No Metrics

1. Check Prometheus targets: http://localhost:9090/targets
2. Verify service endpoints:
   ```bash
   kubectl get endpoints -n ecommerce-poc
   ```

### No Logs in Loki

1. Check Loki status:
   ```bash
   kubectl logs -n monitoring -l app=loki
   ```
2. Verify log shipping from application

### No Traces

1. Check Tempo status:
   ```bash
   kubectl logs -n monitoring -l app=tempo
   ```
2. Verify OpenTelemetry configuration in Node.js app

### PVC Issues

1. Check EBS CSI driver:
   ```bash
   kubectl get pods -n kube-system | grep ebs
   ```
2. Check PVC events:
   ```bash
   kubectl describe pvc -n monitoring
   ```
