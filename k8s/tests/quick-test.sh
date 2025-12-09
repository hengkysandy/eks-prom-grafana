#!/bin/bash
# Quick Test - Generate data for all dashboards in ~2 minutes

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                    QUICK MONITORING TEST                                   ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Setup port forwards
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000 > /dev/null 2>&1 &
PF1=$!
kubectl port-forward -n ecommerce-poc svc/python-orders 5000:5000 > /dev/null 2>&1 &
PF2=$!
kubectl port-forward -n ecommerce-poc svc/go-inventory 8080:8080 > /dev/null 2>&1 &
PF3=$!
sleep 3

cleanup() { kill $PF1 $PF2 $PF3 2>/dev/null || true; }
trap cleanup EXIT

NODE="http://localhost:3000"
PYTHON="http://localhost:5000"
GO="http://localhost:8080"

echo "📗 Generating 2XX requests..."
for i in {1..30}; do
    curl -s "$NODE/health" "$NODE/products" "$NODE/products/1" > /dev/null 2>&1 &
    curl -s "$PYTHON/health" "$PYTHON/orders" > /dev/null 2>&1 &
    curl -s "$GO/health" "$GO/inventory" "$GO/inventory/1" > /dev/null 2>&1 &
done
wait
echo "   ✓ 270 success requests"

echo "📙 Generating 4XX requests..."
for i in {1..20}; do
    curl -s "$NODE/products/999" "$NODE/notfound" > /dev/null 2>&1 &
    curl -s "$PYTHON/orders/999" > /dev/null 2>&1 &
    curl -s "$GO/inventory/999" > /dev/null 2>&1 &
done
wait
echo "   ✓ 80 client errors"

echo "📕 Generating 5XX requests..."
for i in {1..15}; do
    curl -s "$NODE/error/500" "$NODE/error/db" > /dev/null 2>&1 &
    curl -s "$PYTHON/error/500" "$PYTHON/error/db" > /dev/null 2>&1 &
    curl -s "$GO/error/500" "$GO/error/db" > /dev/null 2>&1 &
done
wait
echo "   ✓ 90 server errors"

echo "🔗 Generating cross-service traces..."
for i in {1..10}; do
    curl -s "$NODE/products/1/availability" > /dev/null 2>&1 &
    curl -s -X POST "$NODE/products/1/order" -H "Content-Type: application/json" -d '{"quantity":1}' > /dev/null 2>&1 &
done
wait
echo "   ✓ 20 distributed traces"

echo "⏱️  Generating slow requests..."
curl -s --max-time 10 "$NODE/error/timeout" > /dev/null 2>&1 &
curl -s --max-time 10 "$PYTHON/error/timeout" > /dev/null 2>&1 &
curl -s --max-time 10 "$GO/error/timeout" > /dev/null 2>&1 &
wait
echo "   ✓ 3 timeout requests"

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                         TEST COMPLETE                                      ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Total requests generated: ~463"
echo "   • 2XX: 270"
echo "   • 4XX: 80"
echo "   • 5XX: 90"
echo "   • Traces: 20"
echo "   • Timeouts: 3"
echo ""
echo "🔍 View results:"
echo "   Grafana: kubectl port-forward -n monitoring svc/grafana 3001:3000"
echo "   Open: http://localhost:3001"
