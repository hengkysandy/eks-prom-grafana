#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║           DEPLOYING PRODUCTION-READY MONITORING STACK                      ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Apply all Kubernetes resources
echo "📦 Applying Kubernetes resources..."
kubectl apply -k .

echo ""
echo "⏳ Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=alertmanager -n monitoring --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=120s 2>/dev/null || true

echo ""
echo "📊 Current pod status:"
kubectl get pods -n monitoring
kubectl get pods -n ecommerce-poc

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                    IMPORTING GRAFANA DASHBOARDS                            ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Port forward to Grafana
echo "🔗 Setting up port forward to Grafana..."
kubectl port-forward -n monitoring svc/grafana 3001:3000 > /dev/null 2>&1 &
PF_PID=$!
sleep 5

GRAFANA_URL="http://localhost:3001"
GRAFANA_AUTH="admin:admin"

# Function to import dashboard
import_dashboard() {
    local file=$1
    local name=$2
    
    if [ -f "$file" ]; then
        response=$(curl -s -w "%{http_code}" -o /tmp/grafana_response.txt \
            -X POST "$GRAFANA_URL/api/dashboards/db" \
            -H "Content-Type: application/json" \
            -u "$GRAFANA_AUTH" \
            -d @"$file")
        
        if [ "$response" = "200" ]; then
            echo "  ✅ $name"
        else
            echo "  ⚠️  $name (may already exist)"
        fi
    else
        echo "  ❌ $name - file not found"
    fi
}

echo "Importing dashboards..."
import_dashboard "grafana/dashboards/kubernetes-cluster-overview.json" "Kubernetes Cluster Overview"
import_dashboard "grafana/dashboards/pod-metrics.json" "Pod & Container Metrics"
import_dashboard "grafana/dashboards/application-performance.json" "Application Performance & HTTP Metrics"
import_dashboard "grafana/dashboards/logs-traces.json" "Application Logs & Traces"
import_dashboard "grafana/dashboards/kubernetes-health.json" "Kubernetes Components Health"

# Import existing dashboards
import_dashboard "grafana/observability-dashboard.json" "Microservices Observability"

# Cleanup
kill $PF_PID 2>/dev/null || true

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                         DEPLOYMENT COMPLETE                                ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Access Grafana:"
echo "   kubectl port-forward -n monitoring svc/grafana 3001:3000"
echo "   Open: http://localhost:3001 (admin/admin)"
echo ""
echo "🔔 Access Alertmanager:"
echo "   kubectl port-forward -n monitoring svc/alertmanager 9093:9093"
echo "   Open: http://localhost:9093"
echo ""
echo "📈 Access Prometheus:"
echo "   kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "   Open: http://localhost:9090"
echo ""
echo "📋 Dashboards Available:"
echo "   • Kubernetes Cluster Overview - Node CPU/Memory, PVC usage"
echo "   • Pod & Container Metrics - Per-pod resources"
echo "   • Application Performance - HTTP metrics, latency, errors"
echo "   • Application Logs & Traces - Loki logs, Tempo traces"
echo "   • Kubernetes Components Health - Service status, alerts"
echo ""
echo "🔔 Slack Alerts configured for:"
echo "   • High CPU/Memory usage"
echo "   • Pod crashes and restarts"
echo "   • High error rates"
echo "   • Service downtime"
echo "   • Disk space warnings"
