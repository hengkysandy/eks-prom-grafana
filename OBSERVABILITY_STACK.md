# Cloud-Agnostic Observability Stack

Complete observability setup with Metrics, Logs, and Traces - **no vendor lock-in**.

## Stack Overview

### 🎯 The Three Pillars

1. **Metrics** - Prometheus (cloud-agnostic)
2. **Logs** - Loki (cloud-agnostic)
3. **Traces** - Tempo (cloud-agnostic)
4. **Visualization** - Grafana (unified dashboard)

### ✅ Why This Stack?

- **No vendor lock-in** - Works on any Kubernetes cluster (AWS, GCP, Azure, on-prem)
- **Open source** - All components are free and open source
- **Unified** - Single Grafana dashboard for all observability data
- **Portable** - Easy to migrate between cloud providers
- **Cost-effective** - No per-GB ingestion fees

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Application Pods (Node.js, Python, Go)                      │
│                                                              │
│  ├─ Prometheus metrics (/metrics endpoint)                  │
│  ├─ Structured JSON logs (stdout)                           │
│  └─ OpenTelemetry traces (OTLP)                            │
└─────────────────────────────────────────────────────────────┘
                    │           │           │
                    ▼           ▼           ▼
┌──────────────┐  ┌──────────┐  ┌──────────┐
│  Prometheus  │  │   Loki   │  │  Tempo   │
│  (Metrics)   │  │  (Logs)  │  │ (Traces) │
└──────────────┘  └──────────┘  └──────────┘
                    │           │           │
                    └───────────┴───────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │   Grafana    │
                    │  (Dashboard) │
                    └──────────────┘
```

## Components Deployed

### 1. Prometheus
- **Purpose:** Metrics collection and storage
- **Endpoint:** `http://prometheus-server.monitoring.svc.cluster.local:80`
- **Scrapes:** All microservices `/metrics` endpoints
- **Storage:** emptyDir (ephemeral)

### 2. Loki
- **Purpose:** Log aggregation and querying
- **Endpoint:** `http://loki.monitoring.svc.cluster.local:3100`
- **Collects:** JSON logs from all pods
- **Storage:** emptyDir (ephemeral)

### 3. Tempo
- **Purpose:** Distributed tracing
- **Endpoint:** `http://tempo.monitoring.svc.cluster.local:3200`
- **Protocol:** OTLP (OpenTelemetry)
- **Storage:** emptyDir (ephemeral)

### 4. Grafana
- **Purpose:** Unified visualization
- **Endpoint:** `http://grafana.monitoring.svc.cluster.local:3000`
- **Datasources:** Prometheus, Loki, Tempo (all configured)

## Application Instrumentation

### Node.js Service

**Added:**
- OpenTelemetry SDK for distributed tracing
- Winston for structured JSON logging
- Error tracking metrics (`http_errors_total`)
- Error test endpoints

**Dependencies:**
```json
{
  "@opentelemetry/api": "^1.7.0",
  "@opentelemetry/sdk-node": "^0.45.1",
  "@opentelemetry/auto-instrumentations-node": "^0.40.3",
  "@opentelemetry/exporter-trace-otlp-http": "^0.45.1",
  "winston": "^3.11.0"
}
```

**Tracing Configuration:**
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const sdk = new NodeSDK({
  serviceName: 'nodejs-catalog',
  traceExporter: new OTLPTraceExporter({
    url: 'http://tempo.monitoring.svc.cluster.local:4318/v1/traces',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});
```

**Structured Logging:**
```javascript
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'nodejs-catalog' }
});
```

## Error Test Endpoints

Test observability by triggering different error scenarios:

### 1. Internal Server Error (500)
```bash
curl http://localhost:3000/error/500
```
**What to observe:**
- Metrics: `http_errors_total{error_type="internal_server_error"}` increases
- Logs: Error log with level="error"
- Traces: Span with error status

### 2. Database Error (503)
```bash
curl http://localhost:3000/error/db
```
**What to observe:**
- Metrics: `http_errors_total{error_type="database_error"}` increases
- Logs: Error log with errorType="connection_failed"
- Status code 503 in metrics

### 3. Application Crash
```bash
curl http://localhost:3000/error/crash
```
**What to observe:**
- Metrics: `http_errors_total{error_type="crash"}` increases
- Logs: Unhandled exception with stack trace
- Traces: Failed span

### 4. Timeout Simulation
```bash
curl http://localhost:3000/error/timeout
```
**What to observe:**
- Metrics: High response time in `http_request_duration_seconds`
- Logs: Timeout warning
- Traces: Long-running span

## Grafana Dashboards

### Main Observability Dashboard

**Panels:**
1. **Request Rate** - Requests per second by service
2. **Error Rate** - Errors per second by type
3. **Response Time (p95)** - 95th percentile latency
4. **HTTP Status Codes** - Distribution of status codes
5. **Application Logs** - Real-time log stream
6. **Error Logs** - Filtered error/exception logs
7. **Total Requests** - Counter for last hour
8. **Total Errors** - Error counter for last hour
9. **Avg Response Time** - Average latency
10. **Success Rate %** - Percentage of successful requests

### Accessing Dashboards

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

Open: http://localhost:3001
- Username: `admin`
- Password: `admin`

## Testing the Stack

### Run Error Tests
```bash
cd /Users/hengky/workspace/poc-kiro/k8s
./test-errors.sh
```

### Generate Load
```bash
./load-test.sh 60
```

### View in Grafana

1. **Metrics Tab** - See request rates, error rates, latencies
2. **Logs Tab** - Search logs with LogQL:
   ```
   {namespace="ecommerce-poc"} |~ "error"
   {namespace="ecommerce-poc", app="nodejs-catalog"} | json
   ```
3. **Traces Tab** - View distributed traces (coming soon - need to add trace IDs to logs)

## Key Metrics

### Request Metrics
```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_errors_total[5m])

# Response time p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Success rate
100 * (sum(rate(http_requests_total{status_code=~"2.."}[5m])) / sum(rate(http_requests_total[5m])))
```

### Error Metrics
```promql
# Errors by type
sum(rate(http_errors_total[5m])) by (error_type)

# 5xx errors
sum(rate(http_requests_total{status_code=~"5.."}[5m]))

# 4xx errors
sum(rate(http_requests_total{status_code=~"4.."}[5m]))
```

## Log Queries (LogQL)

### Basic Queries
```logql
# All logs from namespace
{namespace="ecommerce-poc"}

# Logs from specific service
{namespace="ecommerce-poc", app="nodejs-catalog"}

# Error logs
{namespace="ecommerce-poc"} |~ "(?i)error|exception|fail"

# JSON parsing
{namespace="ecommerce-poc"} | json | level="error"
```

### Advanced Queries
```logql
# Count errors per minute
sum(count_over_time({namespace="ecommerce-poc"} |~ "error" [1m])) by (app)

# Average response time from logs
avg_over_time({namespace="ecommerce-poc"} | json | __error__="" | unwrap duration [5m])
```

## Trace Queries

Traces are automatically collected from instrumented applications. In Grafana:

1. Go to **Explore**
2. Select **Tempo** datasource
3. Search by:
   - Service name: `nodejs-catalog`
   - Operation name: `GET /products`
   - Duration: `> 100ms`
   - Status: `error`

## Migration Guide

### Moving to Another Cloud Provider

This stack works on **any Kubernetes cluster**:

1. **AWS EKS** ✅ (current)
2. **Google GKE** ✅
3. **Azure AKS** ✅
4. **On-premise** ✅
5. **DigitalOcean** ✅

**Steps to migrate:**
1. Export Grafana dashboards (JSON)
2. Deploy stack to new cluster (same YAML files)
3. Import dashboards
4. Update DNS/ingress if needed

**No changes needed** - all components are cloud-agnostic!

## Cost Comparison

### AWS Managed (Previous Setup)
- CloudWatch Logs: $825/month (1,500 GB)
- AMP: $51/month
- **Total: $876/month**

### Self-Hosted (Current Setup)
- Prometheus: $0 (included in cluster)
- Loki: $0 (included in cluster)
- Tempo: $0 (included in cluster)
- Storage: ~$10/month (EBS volumes if persistent)
- **Total: ~$10/month** 💰

**Savings: $866/month (98% cheaper!)**

## Production Considerations

### For Production, Add:

1. **Persistent Storage**
   - Use PersistentVolumes instead of emptyDir
   - Loki: S3/GCS/Azure Blob
   - Tempo: S3/GCS/Azure Blob
   - Prometheus: Remote write to long-term storage

2. **High Availability**
   - Run 2+ replicas of each component
   - Use StatefulSets for Loki/Tempo
   - Add load balancers

3. **Retention Policies**
   - Prometheus: 15 days local, 1 year remote
   - Loki: 30 days
   - Tempo: 7 days

4. **Alerting**
   - Configure Alertmanager
   - Set up PagerDuty/Slack integration
   - Define SLOs and alert rules

5. **Security**
   - Enable authentication
   - Use TLS for all endpoints
   - Network policies
   - RBAC

## Next Steps

1. ✅ Add tracing to Python service
2. ✅ Add tracing to Go service
3. ✅ Create service map dashboard
4. ✅ Add exemplars (link metrics to traces)
5. ✅ Set up alerting rules
6. ✅ Add persistent storage
7. ✅ Configure retention policies

## Troubleshooting

### Loki not receiving logs
```bash
# Check Loki is running
kubectl get pods -n monitoring -l app=loki

# Check logs
kubectl logs -n monitoring -l app=loki

# Test Loki API
kubectl port-forward -n monitoring svc/loki 3100:3100
curl http://localhost:3100/ready
```

### Tempo not receiving traces
```bash
# Check Tempo is running
kubectl get pods -n monitoring -l app=tempo

# Check OTLP endpoint
kubectl port-forward -n monitoring svc/tempo 4318:4318
curl http://localhost:4318/v1/traces
```

### Grafana datasources not working
```bash
# Check datasources
kubectl get configmap grafana-datasources -n monitoring -o yaml

# Restart Grafana
kubectl rollout restart deployment grafana -n monitoring
```

## Files

- `k8s/loki/loki-deployment.yaml` - Loki deployment
- `k8s/tempo/tempo-deployment.yaml` - Tempo deployment
- `k8s/grafana/grafana-datasources-all.yaml` - Grafana datasources
- `k8s/grafana/observability-dashboard.json` - Main dashboard
- `k8s/test-errors.sh` - Error testing script
- `apps/nodejs/tracing.js` - OpenTelemetry setup
- `apps/nodejs/app.js` - Instrumented application

## References

- [Grafana Loki](https://grafana.com/oss/loki/)
- [Grafana Tempo](https://grafana.com/oss/tempo/)
- [OpenTelemetry](https://opentelemetry.io/)
- [Prometheus](https://prometheus.io/)
