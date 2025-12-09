#!/bin/bash
# Comprehensive Alert & Metrics Test Suite
# This script orchestrates all test scenarios

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║         COMPREHENSIVE MONITORING TEST SUITE                                ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This test suite will:"
echo "  1. Generate HTTP traffic (2XX, 4XX, 5XX responses)"
echo "  2. Simulate high latency requests"
echo "  3. Generate error logs across all services"
echo "  4. Create distributed traces"
echo "  5. Simulate pod stress (CPU/Memory)"
echo "  6. Test cross-service error propagation"
echo ""
echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
sleep 5

# Setup port forwards
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setting up port forwards..."
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000 > /dev/null 2>&1 &
PF_NODE=$!
kubectl port-forward -n ecommerce-poc svc/python-orders 5000:5000 > /dev/null 2>&1 &
PF_PYTHON=$!
kubectl port-forward -n ecommerce-poc svc/go-inventory 8080:8080 > /dev/null 2>&1 &
PF_GO=$!
sleep 3

cleanup() {
    echo ""
    echo "Cleaning up port forwards..."
    kill $PF_NODE $PF_PYTHON $PF_GO 2>/dev/null || true
}
trap cleanup EXIT

# Run test phases
echo ""
bash "$SCRIPT_DIR/test-http-traffic.sh"
echo ""
bash "$SCRIPT_DIR/test-errors.sh"
echo ""
bash "$SCRIPT_DIR/test-latency.sh"
echo ""
bash "$SCRIPT_DIR/test-cross-service.sh"

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                    ALL TESTS COMPLETED                                     ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 View results in Grafana: http://localhost:3001"
echo "📈 Check Prometheus alerts: http://localhost:9090/alerts"
echo "🔔 Check Alertmanager: http://localhost:9093"
