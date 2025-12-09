#!/bin/bash
# Test Cross-Service Calls - Distributed Tracing

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 4: CROSS-SERVICE CALLS & DISTRIBUTED TRACING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NODE_URL="http://localhost:3000"

echo ""
echo "🔗 Testing: Node.js → Go (availability check)..."
for i in {1..20}; do
    curl -s "$NODE_URL/products/1/availability" > /dev/null 2>&1
    curl -s "$NODE_URL/products/2/availability" > /dev/null 2>&1
    curl -s "$NODE_URL/products/3/availability" > /dev/null 2>&1
    echo -n "."
done
echo " Done!"

echo ""
echo "🔗 Testing: Node.js → Go → Python (full order flow)..."
for i in {1..15}; do
    curl -s -X POST "$NODE_URL/products/1/order" \
        -H "Content-Type: application/json" \
        -d '{"quantity":1}' > /dev/null 2>&1
    curl -s -X POST "$NODE_URL/products/2/order" \
        -H "Content-Type: application/json" \
        -d '{"quantity":2}' > /dev/null 2>&1
    echo -n "."
done
echo " Done!"

echo ""
echo "🔗 Testing: Cross-service with non-existent products..."
for i in {1..10}; do
    curl -s "$NODE_URL/products/999/availability" > /dev/null 2>&1
    curl -s -X POST "$NODE_URL/products/999/order" \
        -H "Content-Type: application/json" \
        -d '{"quantity":1}' > /dev/null 2>&1
    echo -n "."
done
echo " Done!"

echo ""
echo "✅ Cross-Service Test Complete"
echo "   - 60 availability checks (Node.js → Go)"
echo "   - 30 order flows (Node.js → Go → Python)"
echo "   - 20 error propagation tests"
echo ""
echo "🔍 View traces in Tempo:"
echo "   { service.name=\"nodejs-catalog\" }"
echo "   { service.name=\"go-inventory\" }"
echo "   { service.name=\"python-orders\" }"
