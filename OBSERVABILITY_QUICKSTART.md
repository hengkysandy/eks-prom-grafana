# Observability Stack - Quick Start

## ✅ What's Deployed

- **Prometheus** - Metrics collection
- **Loki** - Log aggregation  
- **Tempo** - Distributed tracing
- **Grafana** - Unified dashboard

All running in `monitoring` namespace.

## 🚀 Access Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

Open: **http://localhost:3001**
- Username: `admin`
- Password: `admin`

## 📊 View Observability Data

### 1. Metrics (Prometheus)
- Go to **Explore** → Select **Prometheus**
- Query: `rate(http_requests_total[5m])`

### 2. Logs (Loki)
- Go to **Explore** → Select **Loki**
- Query: `{namespace="ecommerce-poc"}`

### 3. Traces (Tempo)
- Go to **Explore** → Select **Tempo**
- Search by service: `nodejs-catalog`

### 4. Dashboard
- Go to **Dashboards** → **Microservices Observability**

## 🧪 Test Error Scenarios

```bash
cd /Users/hengky/workspace/poc-kiro/k8s
./test-errors.sh
```

This will trigger:
- 500 Internal Server Error
- 503 Database Error
- Application Crash
- 404 Not Found

Then check Grafana to see:
- ✅ Error metrics spike
- ✅ Error logs appear
- ✅ Failed traces recorded

## 📈 Generate Load

```bash
./load-test.sh 60
```

Watch in Grafana:
- Request rate increases
- Response time changes
- Logs flowing in real-time

## 🔍 Useful Queries

### Prometheus (Metrics)
```promql
# Request rate by service
sum(rate(http_requests_total[5m])) by (job)

# Error rate
sum(rate(http_errors_total[5m])) by (error_type)

# Response time p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Success rate %
100 * (sum(rate(http_requests_total{status_code=~"2.."}[5m])) / sum(rate(http_requests_total[5m])))
```

### Loki (Logs)
```logql
# All logs
{namespace="ecommerce-poc"}

# Error logs only
{namespace="ecommerce-poc"} |~ "(?i)error|exception"

# Specific service
{namespace="ecommerce-poc", app="nodejs-catalog"}

# JSON parsing
{namespace="ecommerce-poc"} | json | level="error"
```

### Tempo (Traces)
- Search by service name
- Filter by duration > 100ms
- Filter by status = error

## 🎯 Key Features

### Unified Observability
- **Single dashboard** for metrics, logs, and traces
- **Correlation** - Click from metric → logs → traces
- **No vendor lock-in** - Works on any Kubernetes

### Error Tracking
- Automatic error detection
- Error logs highlighted
- Failed traces marked
- Error rate metrics

### Performance Monitoring
- Request rate tracking
- Response time percentiles (p50, p95, p99)
- Slow query detection
- Resource usage metrics

## 💰 Cost

**Self-hosted:** ~$10/month (storage only)
**vs AWS CloudWatch:** $876/month

**Savings: 98%** 🎉

## 📚 Full Documentation

See `OBSERVABILITY_STACK.md` for complete details.

## 🔧 Troubleshooting

### No logs in Loki?
```bash
# Check Loki is running
kubectl get pods -n monitoring -l app=loki

# Check logs
kubectl logs -n monitoring -l app=loki --tail=50
```

### No traces in Tempo?
```bash
# Check Tempo is running
kubectl get pods -n monitoring -l app=tempo

# Verify OTLP endpoint
kubectl port-forward -n monitoring svc/tempo 4318:4318
curl http://localhost:4318/v1/traces
```

### Grafana datasources not working?
```bash
# Restart Grafana
kubectl rollout restart deployment grafana -n monitoring

# Wait for it to be ready
kubectl rollout status deployment grafana -n monitoring
```

## ✨ Next Steps

1. Explore the dashboard
2. Run error tests
3. Generate some load
4. Search logs for errors
5. View traces for slow requests

Enjoy your cloud-agnostic observability stack! 🚀
