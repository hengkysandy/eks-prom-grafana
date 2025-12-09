#!/bin/bash
# Verify all monitoring data is being collected

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                    MONITORING DATA VERIFICATION                            ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"

# Setup port forwards
kubectl port-forward -n monitoring svc/prometheus 9090:9090 > /dev/null 2>&1 &
PF_PROM=$!
kubectl port-forward -n monitoring svc/loki 3100:3100 > /dev/null 2>&1 &
PF_LOKI=$!
kubectl port-forward -n monitoring svc/tempo 3200:3200 > /dev/null 2>&1 &
PF_TEMPO=$!
sleep 3

cleanup() { kill $PF_PROM $PF_LOKI $PF_TEMPO 2>/dev/null || true; }
trap cleanup EXIT

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📈 PROMETHEUS METRICS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "HTTP Requests Total:"
curl -s 'http://localhost:9090/api/v1/query?query=sum(http_requests_total)%20by%20(job)' | jq -r '.data.result[] | "  \(.metric.job): \(.value[1])"'

echo ""
echo "HTTP Errors Total:"
curl -s 'http://localhost:9090/api/v1/query?query=sum(http_errors_total)%20by%20(job)' | jq -r '.data.result[] | "  \(.metric.job): \(.value[1])"'

echo ""
echo "HTTP Status Code Distribution:"
curl -s 'http://localhost:9090/api/v1/query?query=sum(http_requests_total)%20by%20(status_code)' | jq -r '.data.result[] | "  \(.metric.status_code): \(.value[1])"' | sort

echo ""
echo "Node Memory Usage:"
curl -s 'http://localhost:9090/api/v1/query?query=(1-(node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes))*100' | jq -r '.data.result[] | "  \(.metric.instance | split(":")[0]): \(.value[1] | tonumber | . * 100 | round / 100)%"' | head -2

echo ""
echo "Pod Container Restarts:"
curl -s 'http://localhost:9090/api/v1/query?query=sum(kube_pod_container_status_restarts_total)%20by%20(pod)' | jq -r '.data.result[] | select(.value[1] | tonumber > 0) | "  \(.metric.pod): \(.value[1])"' | head -5

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 LOKI LOGS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Log streams by container:"
curl -s 'http://localhost:3100/loki/api/v1/label/container/values' | jq -r '.data[]' | while read c; do
    echo "  ✓ $c"
done

echo ""
echo "Recent error logs (last 5):"
curl -s 'http://localhost:3100/loki/api/v1/query_range?query={namespace="ecommerce-poc"}|~"(?i)error"&limit=5&start='$(date -v-1H +%s)'000000000&end='$(date +%s)'000000000' 2>/dev/null | jq -r '.data.result[0].values[][1]' 2>/dev/null | head -5 || echo "  (checking...)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 TEMPO TRACES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Services with traces:"
curl -s 'http://localhost:3200/api/search/tag/service.name/values' | jq -r '.tagValues[]' | while read s; do
    echo "  ✓ $s"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔔 ALERTS STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Firing Alerts:"
curl -s 'http://localhost:9090/api/v1/alerts' | jq -r '.data.alerts[] | select(.state=="firing") | "  🔴 \(.labels.alertname)"' || echo "  None"

echo ""
echo "Pending Alerts:"
curl -s 'http://localhost:9090/api/v1/alerts' | jq -r '.data.alerts[] | select(.state=="pending") | "  🟡 \(.labels.alertname)"' || echo "  None"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ VERIFICATION COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
