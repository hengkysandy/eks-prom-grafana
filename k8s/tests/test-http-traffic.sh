#!/bin/bash
# Test HTTP Traffic Generation - 2XX, 4XX, 5XX responses

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 1: HTTP TRAFFIC GENERATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NODE_URL="http://localhost:3000"
PYTHON_URL="http://localhost:5000"
GO_URL="http://localhost:8080"

count_2xx=0
count_4xx=0
count_5xx=0

# Function to make request and track status
make_request() {
    local url=$1
    local method=${2:-GET}
    local data=${3:-}
    
    if [ "$method" = "POST" ]; then
        status=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null)
    else
        status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    fi
    
    if [[ $status -ge 200 && $status -lt 300 ]]; then
        ((count_2xx++))
    elif [[ $status -ge 400 && $status -lt 500 ]]; then
        ((count_4xx++))
    elif [[ $status -ge 500 ]]; then
        ((count_5xx++))
    fi
}

echo ""
echo "📗 Generating 2XX Success Requests..."
for i in {1..50}; do
    make_request "$NODE_URL/health"
    make_request "$NODE_URL/products"
    make_request "$NODE_URL/products/1"
    make_request "$PYTHON_URL/health"
    make_request "$PYTHON_URL/orders"
    make_request "$GO_URL/health"
    make_request "$GO_URL/inventory"
    echo -n "."
done
echo ""

echo ""
echo "📙 Generating 4XX Client Error Requests..."
for i in {1..30}; do
    make_request "$NODE_URL/products/999"      # 404
    make_request "$NODE_URL/nonexistent"       # 404
    make_request "$PYTHON_URL/orders/999"      # 404
    make_request "$GO_URL/inventory/999"       # 404
    echo -n "."
done
echo ""

echo ""
echo "📕 Generating 5XX Server Error Requests..."
for i in {1..20}; do
    make_request "$NODE_URL/error/500"
    make_request "$NODE_URL/error/db"
    make_request "$PYTHON_URL/error/500"
    make_request "$PYTHON_URL/error/db"
    make_request "$GO_URL/error/500"
    make_request "$GO_URL/error/db"
    echo -n "."
done
echo ""

echo ""
echo "✅ HTTP Traffic Summary:"
echo "   2XX responses: $count_2xx"
echo "   4XX responses: $count_4xx"
echo "   5XX responses: $count_5xx"
echo "   Total requests: $((count_2xx + count_4xx + count_5xx))"
