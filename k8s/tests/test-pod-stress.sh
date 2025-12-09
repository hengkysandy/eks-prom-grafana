#!/bin/bash
# Test Pod Stress - CPU/Memory alerts (requires stress tool in pod)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "POD STRESS TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  This test creates high load on pods to trigger CPU/Memory alerts"
echo ""

# Deploy stress test pod
echo "📦 Deploying stress test pod..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: stress-test
  namespace: ecommerce-poc
spec:
  containers:
  - name: stress
    image: progrium/stress
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
EOF

echo "⏳ Waiting for stress pod to be ready..."
kubectl wait --for=condition=ready pod/stress-test -n ecommerce-poc --timeout=60s 2>/dev/null || true

echo ""
echo "🔥 Running CPU stress test (30 seconds)..."
kubectl exec -n ecommerce-poc stress-test -- stress --cpu 2 --timeout 30s 2>/dev/null &
STRESS_PID=$!

echo "   Stress test running in background..."
echo "   Check Prometheus for high CPU alerts"
echo ""

# Wait for stress to complete
sleep 35

echo ""
echo "🔥 Running Memory stress test (30 seconds)..."
kubectl exec -n ecommerce-poc stress-test -- stress --vm 1 --vm-bytes 200M --timeout 30s 2>/dev/null &

sleep 35

echo ""
echo "🧹 Cleaning up stress test pod..."
kubectl delete pod stress-test -n ecommerce-poc --force --grace-period=0 2>/dev/null || true

echo ""
echo "✅ Pod Stress Test Complete"
echo "   - CPU stress: 30 seconds"
echo "   - Memory stress: 30 seconds"
echo ""
echo "📊 Check alerts in Prometheus/Alertmanager"
