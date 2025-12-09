#!/bin/bash
# Quick access script for Kubernetes Dashboard

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                    KUBERNETES DASHBOARD ACCESS                             ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Get token
TOKEN=$(kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 --decode)

echo "🔑 Access Token:"
echo ""
echo "$TOKEN"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Starting port-forward..."
echo "   Dashboard will be available at: https://localhost:8443"
echo ""
echo "   Press Ctrl+C to stop"
echo ""

kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
