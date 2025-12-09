#!/bin/bash
# Test Alert Triggers - Simulate conditions that trigger specific alerts

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ALERT TRIGGER SIMULATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This script simulates conditions to trigger various alerts."
echo "Alerts require sustained conditions (typically 2-5 minutes)."
echo ""

NODE_URL="http://localhost:3000"
PYTHON_URL="http://localhost:5000"
GO_URL="http://localhost:8080"

# HighErrorRate Alert (>5% error rate for 5m)
echo "🔔 Triggering: HighErrorRate Alert"
echo "   Generating >5% error rate..."
for i in {1..100}; do
    # 10 errors per 90 success = ~10% error rate
    curl -s "$NODE_URL/health" > /dev/null 2>&1
    curl -s "$NODE_URL/products" > /dev/null 2>&1
    curl -s "$NODE_URL/products/1" > /dev/null 2>&1
    curl -s "$PYTHON_URL/health" > /dev/null 2>&1
    curl -s "$PYTHON_URL/orders" > /dev/null 2>&1
    curl -s "$GO_URL/health" > /dev/null 2>&1
    curl -s "$GO_URL/inventory" > /dev/null 2>&1
    curl -s "$GO_URL/inventory/1" > /dev/null 2>&1
    curl -s "$GO_URL/inventory/2" > /dev/null 2>&1
    # Errors
    curl -s "$NODE_URL/error/500" > /dev/null 2>&1
    echo -n "."
done
echo " Done!"

# High5xxRate Alert (>1% 5xx rate for 5m)
echo ""
echo "🔔 Triggering: High5xxRate Alert"
echo "   Generating 5xx errors..."
for i in {1..50}; do
    curl -s "$NODE_URL/error/500" > /dev/null 2>&1
    curl -s "$PYTHON_URL/error/500" > /dev/null 2>&1
    curl -s "$GO_URL/error/500" > /dev/null 2>&1
    curl -s "$NODE_URL/error/db" > /dev/null 2>&1
    curl -s "$PYTHON_URL/error/db" > /dev/null 2>&1
    curl -s "$GO_URL/error/db" > /dev/null 2>&1
    echo -n "."
done
echo " Done!"

# High4xxRate Alert (>20% 4xx rate for 5m)
echo ""
echo "🔔 Triggering: High4xxRate Alert"
echo "   Generating 4xx errors..."
for i in {1..100}; do
    curl -s "$NODE_URL/products/$RANDOM" > /dev/null 2>&1
    curl -s "$PYTHON_URL/orders/$RANDOM" > /dev/null 2>&1
    curl -s "$GO_URL/inventory/$RANDOM" > /dev/null 2>&1
    curl -s "$NODE_URL/nonexistent" > /dev/null 2>&1
    echo -n "."
done
echo " Done!"

# HighResponseTime Alert (P95 > 2s for 5m)
echo ""
echo "🔔 Triggering: HighResponseTime Alert"
echo "   Generating slow requests..."
for i in {1..5}; do
    curl -s --max-time 10 "$NODE_URL/error/timeout" > /dev/null 2>&1 &
    curl -s --max-time 10 "$PYTHON_URL/error/timeout" > /dev/null 2>&1 &
    curl -s --max-time 10 "$GO_URL/error/timeout" > /dev/null 2>&1 &
done
wait
echo " Done!"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Alert Trigger Simulation Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Alerts triggered (check after 2-5 minutes):"
echo "   • HighErrorRate - Error rate > 5%"
echo "   • High5xxRate - 5xx rate > 1%"
echo "   • High4xxRate - 4xx rate > 20%"
echo "   • HighResponseTime - P95 > 2s"
echo ""
echo "🔍 Check alerts:"
echo "   Prometheus: http://localhost:9090/alerts"
echo "   Alertmanager: http://localhost:9093"
echo "   Slack: Check #alerts channel"
