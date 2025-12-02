#!/bin/bash

echo "=========================================="
echo "Starting Load Test for E-Commerce Services"
echo "=========================================="
echo ""

# Deploy load test pod
kubectl run load-test --image=busybox --restart=Never -n ecommerce-poc --rm -i -- sh -c '
echo "Load test started..."
echo ""

# Phase 1: Light load (10 req/sec for 30 seconds)
echo "Phase 1: Light load (10 req/sec)..."
for i in $(seq 1 300); do
  wget -q -O- http://nodejs-catalog:3000/products &
  wget -q -O- http://python-orders:5000/orders &
  wget -q -O- http://go-inventory:8080/inventory &
  sleep 0.1
done
wait
echo "Phase 1 complete: 900 requests sent"
echo ""

# Phase 2: Medium load (50 req/sec for 30 seconds)
echo "Phase 2: Medium load (50 req/sec)..."
for i in $(seq 1 1500); do
  wget -q -O- http://nodejs-catalog:3000/products &
  wget -q -O- http://python-orders:5000/orders &
  wget -q -O- http://go-inventory:8080/inventory &
  sleep 0.02
done
wait
echo "Phase 2 complete: 4,500 requests sent"
echo ""

# Phase 3: Heavy load (100 req/sec for 30 seconds)
echo "Phase 3: Heavy load (100 req/sec)..."
for i in $(seq 1 3000); do
  wget -q -O- http://nodejs-catalog:3000/products &
  wget -q -O- http://python-orders:5000/orders &
  wget -q -O- http://go-inventory:8080/inventory &
  sleep 0.01
done
wait
echo "Phase 3 complete: 9,000 requests sent"
echo ""

# Phase 4: Spike test (200 req/sec for 15 seconds)
echo "Phase 4: Spike test (200 req/sec)..."
for i in $(seq 1 3000); do
  wget -q -O- http://nodejs-catalog:3000/products &
  wget -q -O- http://python-orders:5000/orders &
  wget -q -O- http://go-inventory:8080/inventory &
  sleep 0.005
done
wait
echo "Phase 4 complete: 9,000 requests sent"
echo ""

echo "=========================================="
echo "Load test completed!"
echo "Total requests: ~23,400"
echo "=========================================="
'

echo ""
echo "Load test finished. Check Grafana dashboard for metrics:"
echo "http://localhost:3001/d/ead7cc76-3a4e-4169-b8c1-11ff58faea86/e-commerce-microservices-dashboard"
