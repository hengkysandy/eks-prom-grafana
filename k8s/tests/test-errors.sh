#!/bin/bash
# Test Error Generation - Logs and Metrics

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 2: ERROR LOG GENERATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NODE_URL="http://localhost:3000"
PYTHON_URL="http://localhost:5000"
GO_URL="http://localhost:8080"

echo ""
echo "🔴 Generating Internal Server Errors (500)..."
for i in {1..15}; do
    curl -s "$NODE_URL/error/500" > /dev/null 2>&1
    curl -s "$PYTHON_URL/error/500" > /dev/null 2>&1
    curl -s "$GO_URL/error/500" > /dev/null 2>&1
    echo -n "."
done
echo " Done!"

echo ""
echo "🔴 Generating Database Connection Errors (503)..."
for i in {1..15}; do
    curl -s "$NODE_URL/error/db" > /dev/null 2>&1
    curl -s "$PYTHON_URL/error/db" > /dev/null 2>&1
    curl -s "$GO_URL/error/db" > /dev/null 2>&1
    echo -n "."
done
echo " Done!"

echo ""
echo "🔴 Generating Not Found Errors (404)..."
for i in {1..20}; do
    curl -s "$NODE_URL/products/$RANDOM" > /dev/null 2>&1
    curl -s "$PYTHON_URL/orders/$RANDOM" > /dev/null 2>&1
    curl -s "$GO_URL/inventory/$RANDOM" > /dev/null 2>&1
    echo -n "."
done
echo " Done!"

echo ""
echo "🔴 Triggering Application Crash Endpoint..."
for i in {1..5}; do
    curl -s "$NODE_URL/error/crash" > /dev/null 2>&1 || true
    echo -n "."
done
echo " Done!"

echo ""
echo "✅ Error Generation Complete"
echo "   - 45 Internal Server Errors (500)"
echo "   - 45 Database Errors (503)"
echo "   - 60 Not Found Errors (404)"
echo "   - 5 Crash simulations"
echo ""
echo "📋 Check Loki for error logs:"
echo "   {namespace=\"ecommerce-poc\"} |~ \"(?i)error\""
