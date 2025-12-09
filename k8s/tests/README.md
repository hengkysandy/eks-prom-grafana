# Monitoring Test Suite

Comprehensive test scripts to generate metrics, logs, traces, and trigger alerts.

## Quick Start

```bash
# Run quick test (~2 minutes)
./quick-test.sh

# Run all tests (~5 minutes)
./run-all-tests.sh

# Verify data collection
./verify-data.sh
```

## Test Scripts

### 1. quick-test.sh
Fast test that generates data for all dashboards in ~2 minutes.
- 270 success requests (2XX)
- 80 client errors (4XX)
- 90 server errors (5XX)
- 20 distributed traces
- 3 timeout requests

### 2. run-all-tests.sh
Orchestrates all test phases sequentially.

### 3. test-http-traffic.sh
Generates HTTP traffic with various status codes:
- 2XX success responses
- 4XX client errors (404 Not Found)
- 5XX server errors (500, 503)

### 4. test-errors.sh
Generates error logs across all services:
- Internal Server Errors (500)
- Database Connection Errors (503)
- Not Found Errors (404)
- Application Crash simulations

### 5. test-latency.sh
Simulates high latency requests:
- Timeout requests (5s delay)
- Mixed latency traffic for P95/P98/P99 metrics

### 6. test-cross-service.sh
Tests distributed tracing:
- Node.js → Go (availability check)
- Node.js → Go → Python (full order flow)
- Error propagation across services

### 7. test-alert-triggers.sh
Simulates conditions to trigger alerts:
- HighErrorRate (>5% error rate)
- High5xxRate (>1% 5xx rate)
- High4xxRate (>20% 4xx rate)
- HighResponseTime (P95 > 2s)

### 8. test-pod-stress.sh
Stress tests pods to trigger resource alerts:
- CPU stress (30 seconds)
- Memory stress (30 seconds)
- Requires stress tool in pod

### 9. verify-data.sh
Verifies all monitoring data is being collected:
- Prometheus metrics
- Loki logs
- Tempo traces
- Alert status

## Expected Results

### Metrics Generated
| Metric | Expected Count |
|--------|---------------|
| HTTP Requests | 10,000+ |
| HTTP Errors | 1,000+ |
| 2XX Responses | 9,000+ |
| 4XX Responses | 300+ |
| 5XX Responses | 300+ |

### Alerts Triggered
| Alert | Condition |
|-------|-----------|
| CriticalErrorRate | Error rate > 10% |
| HighErrorRate | Error rate > 5% |
| High5xxRate | 5xx rate > 1% |
| High4xxRate | 4xx rate > 20% |

### Logs Collected
- All 3 application services (nodejs, python, go)
- All monitoring components
- Kubernetes system components

### Traces Collected
- nodejs-catalog
- go-inventory
- python-orders

## Viewing Results

### Grafana Dashboards
```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
# Open: http://localhost:3001 (admin/admin)
```

Dashboards to check:
1. **Kubernetes Cluster Overview** - Node metrics, PVC usage
2. **Pod & Container Metrics** - Per-pod resources
3. **Application Performance** - HTTP metrics, latency
4. **Application Logs & Traces** - Loki logs, Tempo traces
5. **Kubernetes Components Health** - Service status, alerts

### Prometheus Alerts
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/alerts
```

### Alertmanager
```bash
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Open: http://localhost:9093
```

### Slack
Check your #alerts channel for notifications.

## Troubleshooting

### No metrics showing
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'
```

### No logs in Loki
```bash
# Check Promtail
kubectl logs -n monitoring -l app=promtail --tail=20
```

### No traces in Tempo
```bash
# Check services sending traces
kubectl port-forward -n monitoring svc/tempo 3200:3200
curl http://localhost:3200/api/search/tag/service.name/values
```

### Alerts not firing
```bash
# Check alert rules loaded
kubectl port-forward -n monitoring svc/prometheus 9090:9090
curl http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[].name'
```
