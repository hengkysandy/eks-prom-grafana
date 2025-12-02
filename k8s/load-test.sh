#!/bin/bash
# Quick load test script for e-commerce microservices
# Usage: ./load-test.sh [duration_in_seconds]

DURATION=${1:-30}

echo "Running load test for ${DURATION} seconds..."
echo "Sending requests to all 3 services..."

kubectl exec -n ecommerce-poc traffic-generator -- sh -c "
for i in \$(seq 1 ${DURATION}); do
  wget -q -O- http://nodejs-catalog.ecommerce-poc.svc.cluster.local:3000/products > /dev/null &
  wget -q -O- http://python-orders.ecommerce-poc.svc.cluster.local:5000/orders > /dev/null &
  wget -q -O- http://go-inventory.ecommerce-poc.svc.cluster.local:8080/inventory > /dev/null &
  sleep 1
done
wait
echo 'Load test complete: $((${DURATION} * 3)) requests sent'
"

echo "✅ Load test complete!"
echo "Check metrics in Grafana: http://localhost:3001"
