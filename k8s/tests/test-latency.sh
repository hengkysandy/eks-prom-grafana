#!/bin/bash
# Test High Latency Requests - P95/P98/P99 metrics

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 3: LATENCY SIMULATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NODE_URL="http://localhost:3000"
PYTHON_URL="http://localhost:5000"
GO_URL="http://localhost:8080"

echo ""
echo "⏱️  Generating timeout requests (5s delay each)..."
echo "   This will take ~30 seconds..."

# Run timeout requests in background to parallelize
for i in {1..2}; do
    curl -s --max-time 10 "$NODE_URL/error/timeout" > /dev/null 2>&1 &
    curl -s --max-time 10 "$PYTHON_URL/error/timeout" > /dev/null 2>&1 &
    curl -s --max-time 10 "$GO_URL/error/timeout" > /dev/null 2>&1 &
done
wait
echo "   ✓ Timeout requests completed"

echo ""
echo "⏱️  Generating mixed latency traffic..."
echo "   Fast requests + slow requests to create latency distribution"

for i in {1..30}; do
    # Fast requests
    curl -s "$NODE_URL/health" > /dev/null 2>&1 &
    curl -s "$PYTHON_URL/health" > /dev/null 2>&1 &
    curl -s "$GO_URL/health" > /dev/null 2>&1 &
    
    # Medium requests (with some processing)
    curl -s "$NODE_URL/products" > /dev/null 2>&1 &
    curl -s "$PYTHON_URL/orders" > /dev/null 2>&1 &
    curl -s "$GO_URL/inventory" > /dev/null 2>&1 &
    
    echo -n "."
done
wait
echo ""

echo ""
echo "✅ Latency Simulation Complete"
echo "   - 6 timeout requests (5s each)"
echo "   - 180 mixed latency requests"
echo ""
echo "📊 Check P95/P98/P99 in Application Performance dashboard"
