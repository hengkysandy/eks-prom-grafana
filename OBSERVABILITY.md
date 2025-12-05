# Observability Guide

Complete guide to logs, metrics, and traces in the e-commerce microservices PoC.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Accessing Grafana](#accessing-grafana)
- [Viewing Metrics](#viewing-metrics)
- [Viewing Logs](#viewing-logs)
- [Viewing Traces](#viewing-traces)
- [Cross-Service Tracing](#cross-service-tracing)
- [Troubleshooting](#troubleshooting)

## Overview

This PoC uses a **cloud-agnostic observability stack**:

| Component | Purpose | Storage | Retention |
|-----------|---------|---------|-----------|
| **Prometheus** | Metrics collection | emptyDir (8Gi) | ~2 hours |
| **AMP** | Long-term metrics | AWS Managed | 150 days |
| **Loki** | Log aggregation | emptyDir | Ephemeral |
| **Tempo** | Distributed tracing | emptyDir | 1 hour |
| **Grafana** | Visualization | emptyDir | N/A |

**Note:** Using emptyDir means data is lost on pod restart. For production, use PersistentVolumeClaims.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User Request                                │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│  Node.js Catalog Service                                            │
│  ├─ Metrics: /metrics (Prometheus format)                           │
│  ├─ Logs: winston → winston-loki → Loki                            │
│  └─ Traces: OpenTelemetry → Tempo                                  │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│  Go Inventory Service                                               │
│  ├─ Metrics: /metrics (Prometheus format)                           │
│  ├─ Logs: JSON to stdout → CloudWatch                              │
│  └─ Traces: Not instrumented yet                                   │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│  Python Orders Service                                              │
│  ├─ Metrics: /metrics (Prometheus format)                           │
│  ├─ Logs: JSON to stdout → CloudWatch                              │
│  └─ Traces: Not instrumented yet                                   │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Observability Stack                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  Prometheus  │  │     Loki     │  │    Tempo     │             │
│  │  (Metrics)   │  │    (Logs)    │  │   (Traces)   │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│         ↓                  ↓                  ↓                     │
│  ┌─────────────────────────────────────────────────────┐           │
│  │              Grafana (Visualization)                │           │
│  └─────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

## Accessing Grafana

### 1. Port-forward Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

### 2. Open in Browser

- URL: http://localhost:3001
- Username: `admin`
- Password: `admin`

### 3. Datasources (Pre-configured)

- **Prometheus** (default): http://prometheus.monitoring.svc.cluster.local:9090
- **AMP**: Amazon Managed Prometheus with SigV4 auth
- **Loki**: http://loki.monitoring.svc.cluster.local:3100
- **Tempo**: http://tempo.monitoring.svc.cluster.local:3200

## Viewing Metrics

### In Grafana Explore

1. Click **Explore** (compass icon) in left sidebar
2. Select **Prometheus** datasource
3. Try these queries:

**Request Rate:**
```promql
rate(http_requests_total[5m])
```

**Error Rate:**
```promql
rate(http_requests_total{status_code=~"5.."}[5m])
```

**Response Time (p95):**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**Pod Status:**
```promql
kube_pod_status_phase{namespace="ecommerce-poc"}
```

### Using Dashboards

Import pre-built dashboards:

```bash
cd k8s/grafana
./import-dashboards.sh
```

This imports:
- Dashboard 3119: Kubernetes Cluster Monitoring
- Dashboard 8588: Kubernetes Deployment Metrics
- Dashboard 15760: Kubernetes Views Pods

### Via CLI (Prometheus API)

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Query current metrics
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result'

# Query time range
curl -s 'http://localhost:9090/api/v1/query_range?query=rate(http_requests_total[5m])&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s' | jq
```

## Viewing Logs

### In Grafana Explore

1. Click **Explore** in left sidebar
2. Select **Loki** datasource
3. Try these queries:

**All Node.js logs:**
```logql
{app="nodejs-catalog"}
```

**Error logs only:**
```logql
{app="nodejs-catalog"} |= "error"
```

**HTTP 500 errors:**
```logql
{app="nodejs-catalog"} | json | statusCode="500"
```

**Logs with trace correlation:**
```logql
{app="nodejs-catalog"} | json | trace_id != ""
```

**Filter by time range:**
```logql
{app="nodejs-catalog"} |= "order" | json | __timestamp__ > 1h
```

### Via CLI (Loki API)

```bash
# Port-forward Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Query logs
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={app="nodejs-catalog"}' \
  --data-urlencode 'limit=10' | jq '.data.result'

# Query with time range
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={app="nodejs-catalog"} |= "error"' \
  --data-urlencode 'start=1609459200' \
  --data-urlencode 'end=1609545600' | jq
```

### Via kubectl (Pod logs)

```bash
# Real-time logs
kubectl logs -n ecommerce-poc deployment/nodejs-catalog -f

# Last 50 lines
kubectl logs -n ecommerce-poc deployment/nodejs-catalog --tail=50

# Filter JSON logs
kubectl logs -n ecommerce-poc deployment/nodejs-catalog --tail=100 | grep '"level":"error"' | jq
```

### Via CloudWatch (Fargate logs)

```bash
# Tail logs
aws logs tail /aws/eks/ecommerce-poc-eks/application --follow --region ap-southeast-1

# Filter by service
aws logs tail /aws/eks/ecommerce-poc-eks/application --follow --filter-pattern "nodejs-catalog" --region ap-southeast-1
```

## Viewing Traces

### In Grafana Explore

1. Click **Explore** in left sidebar
2. Select **Tempo** datasource
3. Search options:

**By Service Name:**
- Service Name: `nodejs-catalog`
- Click **Run Query**

**By Status Code:**
- Tags: `http.status_code=500`
- Find all error traces

**By Duration:**
- Min Duration: `20ms`
- Find slow requests

**By Trace ID:**
- Trace ID: `dea7c49256afd060d5159cba9440aa2f`
- View specific trace

### Via CLI (Tempo API)

```bash
# Port-forward Tempo
kubectl port-forward -n monitoring svc/tempo 3200:3200

# Search traces by service
curl -s "http://localhost:3200/api/search?tags=service.name=nodejs-catalog&limit=10" | jq

# Search error traces
curl -s "http://localhost:3200/api/search?tags=http.status_code=500&limit=5" | jq

# Get specific trace
TRACE_ID="dea7c49256afd060d5159cba9440aa2f"
curl -s "http://localhost:3200/api/traces/$TRACE_ID" | jq
```

### Trace Structure

Each trace contains:
- **Trace ID**: Unique identifier across all services
- **Spans**: Individual operations within the trace
- **Span ID**: Unique identifier for each span
- **Parent Span ID**: Links spans together
- **Attributes**: HTTP method, URL, status code, etc.
- **Duration**: Time taken for the operation

Example trace:
```json
{
  "traceID": "dea7c49256afd060d5159cba9440aa2f",
  "rootServiceName": "nodejs-catalog",
  "spans": [
    {
      "spanID": "abc123",
      "name": "GET /error/500",
      "kind": "SPAN_KIND_SERVER",
      "duration": "2.02ms",
      "attributes": {
        "http.method": "GET",
        "http.status_code": 500
      }
    }
  ]
}
```

## Cross-Service Tracing

### Current State

**Instrumented:**
- ✅ Node.js Catalog: Full OpenTelemetry instrumentation

**Not Instrumented:**
- ❌ Go Inventory: Needs OpenTelemetry SDK
- ❌ Python Orders: Needs OpenTelemetry SDK

### Testing Cross-Service Calls

```bash
# Port-forward Node.js service
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000

# Check product availability (Node.js → Go)
curl http://localhost:3000/products/1/availability

# Place order (Node.js → Go → Python)
curl -X POST http://localhost:3000/products/2/order
```

### Finding Trace ID

**From logs:**
```bash
kubectl logs -n ecommerce-poc deployment/nodejs-catalog --tail=20 | grep "order" | jq '.trace_id'
```

**From response headers (if configured):**
```bash
curl -v http://localhost:3000/products/1/order 2>&1 | grep -i trace
```

### Correlating Logs and Traces

1. **Find log entry in Loki:**
   ```logql
   {app="nodejs-catalog"} |= "order"
   ```

2. **Click on trace_id field** in log entry

3. **Grafana automatically jumps to Tempo** with that trace ID

4. **View full trace timeline** with all spans

## Troubleshooting

### Prometheus Not Scraping

**Check targets:**
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
curl http://localhost:9090/targets
```

**Check ServiceMonitor:**
```bash
kubectl get servicemonitor -n monitoring
kubectl describe servicemonitor prometheus -n monitoring
```

**Check pod labels:**
```bash
kubectl get pods -n ecommerce-poc --show-labels
```

### Loki Not Receiving Logs

**Check Loki status:**
```bash
kubectl logs -n monitoring deployment/loki
```

**Check winston-loki configuration:**
```bash
kubectl exec -n ecommerce-poc deployment/nodejs-catalog -- cat /app/app.js | grep -A 10 "winston-loki"
```

**Test Loki endpoint:**
```bash
kubectl port-forward -n monitoring svc/loki 3100:3100
curl http://localhost:3100/ready
```

### Tempo Not Receiving Traces

**Check Tempo status:**
```bash
kubectl logs -n monitoring deployment/tempo
```

**Check OpenTelemetry configuration:**
```bash
kubectl exec -n ecommerce-poc deployment/nodejs-catalog -- cat /app/tracing.js
```

**Test Tempo endpoint:**
```bash
kubectl port-forward -n monitoring svc/tempo 3200:3200
curl http://localhost:3200/ready
```

### Grafana Datasource Issues

**Check datasource configuration:**
```bash
kubectl get configmap -n monitoring grafana-datasources -o yaml
```

**Test connectivity from Grafana pod:**
```bash
kubectl exec -n monitoring deployment/grafana -- wget -O- http://prometheus.monitoring.svc.cluster.local:9090/-/healthy
kubectl exec -n monitoring deployment/grafana -- wget -O- http://loki.monitoring.svc.cluster.local:3100/ready
kubectl exec -n monitoring deployment/grafana -- wget -O- http://tempo.monitoring.svc.cluster.local:3200/ready
```

### No Data in Dashboards

**Check time range:**
- Ensure time range in Grafana matches when data was generated
- Default: Last 6 hours

**Generate test traffic:**
```bash
cd k8s
./load-test.sh 60
```

**Check pod status:**
```bash
kubectl get pods -n ecommerce-poc
kubectl get pods -n monitoring
```

## Best Practices

### For Production

1. **Use Persistent Storage:**
   - Add PersistentVolumeClaims to Loki, Tempo, Grafana
   - Configure S3 backend for Loki and Tempo
   - Increase retention periods

2. **Add OpenTelemetry to All Services:**
   - Instrument Python and Go services
   - Propagate trace context via HTTP headers
   - Enable full distributed tracing

3. **Configure Alerting:**
   - Set up Prometheus AlertManager
   - Create alert rules for errors, latency, downtime
   - Integrate with PagerDuty, Slack, etc.

4. **Secure Access:**
   - Enable authentication on Grafana
   - Use TLS for all connections
   - Implement RBAC for datasources

5. **Optimize Costs:**
   - Adjust retention periods based on needs
   - Use sampling for high-volume traces
   - Consider managed services for critical components

### Query Performance

**Use recording rules for expensive queries:**
```yaml
groups:
  - name: example
    interval: 30s
    rules:
      - record: job:http_requests:rate5m
        expr: rate(http_requests_total[5m])
```

**Limit log queries:**
```logql
{app="nodejs-catalog"} | json | limit 1000
```

**Use appropriate time ranges:**
- Don't query months of data unnecessarily
- Use smaller step intervals for detailed views

## Additional Resources

- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Tempo TraceQL](https://grafana.com/docs/tempo/latest/traceql/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
