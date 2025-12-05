#!/bin/bash

echo "Testing error endpoints..."

# Port forward in background
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

echo "1. Testing 500 error..."
curl -s http://localhost:3000/error/500 | jq

echo -e "\n2. Testing database error..."
curl -s http://localhost:3000/error/db | jq

echo -e "\n3. Testing crash error..."
curl -s http://localhost:3000/error/crash | jq

echo -e "\n4. Testing normal request..."
curl -s http://localhost:3000/products | jq '.count'

echo -e "\n5. Testing 404 error..."
curl -s http://localhost:3000/products/999 | jq

# Kill port-forward
kill $PF_PID 2>/dev/null

echo -e "\n✅ Error tests complete! Check Grafana for logs and traces."
