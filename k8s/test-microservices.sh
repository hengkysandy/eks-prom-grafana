#!/bin/bash

echo "🧪 Testing Microservices with Cross-Service Calls"
echo "=================================================="

# Port forward in background
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

echo ""
echo "1️⃣  Testing Product Availability (Node.js → Go)"
echo "   Calls: nodejs-catalog → go-inventory"
curl -s http://localhost:3000/products/1/availability | jq

echo ""
echo "2️⃣  Testing Order Creation (Node.js → Go → Python)"
echo "   Calls: nodejs-catalog → go-inventory → python-orders"
curl -s -X POST http://localhost:3000/products/1/order \
  -H "Content-Type: application/json" \
  -d '{"quantity": 2}' | jq

echo ""
echo "3️⃣  Testing Node.js Error"
curl -s http://localhost:3000/error/500 | jq

echo ""
echo "4️⃣  Testing Python Error"
curl -s http://localhost:5000/error/500 2>/dev/null || echo "   (Python service not accessible from localhost)"

echo ""
echo "5️⃣  Testing Go Error"
curl -s http://localhost:8080/error/500 2>/dev/null || echo "   (Go service not accessible from localhost)"

echo ""
echo "6️⃣  Testing Service Unavailable Scenario"
echo "   Simulating downstream service failure..."
curl -s http://localhost:3000/error/db | jq

echo ""
echo "7️⃣  Testing Normal Flow"
curl -s http://localhost:3000/products | jq '.count'

# Kill port-forward
kill $PF_PID 2>/dev/null

echo ""
echo "✅ Tests complete!"
echo ""
echo "📊 Check Grafana for:"
echo "   - Loki: {app=\"nodejs-catalog\"} or {namespace=\"ecommerce-poc\"}"
echo "   - Tempo: Service = nodejs-catalog"
echo "   - Metrics: http_requests_total, http_errors_total"
echo ""
echo "🔗 Cross-service traces should show:"
echo "   nodejs-catalog → go-inventory → python-orders"
