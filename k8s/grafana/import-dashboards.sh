#!/bin/bash
# Import popular Grafana dashboards for Kubernetes monitoring
# Run this after port-forwarding Grafana: kubectl port-forward -n monitoring svc/grafana 3001:3000

set -e

GRAFANA_URL="http://admin:admin@localhost:3001"

echo "Importing Grafana dashboards..."

# Dashboard 3119: Kubernetes Cluster Monitoring via Prometheus
echo "Importing dashboard 3119 (Kubernetes Cluster Monitoring)..."
curl -s "https://grafana.com/api/dashboards/3119" | jq -r '.json' | jq '. + {id: null}' > /tmp/dashboard-3119.json
curl -X POST ${GRAFANA_URL}/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $(cat /tmp/dashboard-3119.json), \"overwrite\": true}" | jq .

# Dashboard 8588: Kubernetes Deployment Statefulset Daemonset metrics
echo "Importing dashboard 8588 (Kubernetes Deployment metrics)..."
curl -s "https://grafana.com/api/dashboards/8588" | jq -r '.json' | jq '. + {id: null}' > /tmp/dashboard-8588.json
curl -X POST ${GRAFANA_URL}/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $(cat /tmp/dashboard-8588.json), \"overwrite\": true}" | jq .

# Dashboard 15760: Kubernetes Views Pods
echo "Importing dashboard 15760 (Kubernetes Views Pods)..."
curl -s "https://grafana.com/api/dashboards/15760" | jq -r '.json' | jq '. + {id: null}' > /tmp/dashboard-15760.json
curl -X POST ${GRAFANA_URL}/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $(cat /tmp/dashboard-15760.json), \"overwrite\": true}" | jq .

echo "✅ All dashboards imported successfully!"
echo "Access Grafana at: http://localhost:3001"
