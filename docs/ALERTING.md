# Alerting System Documentation

## Overview

This project uses Prometheus Alertmanager for alerting with Slack integration.

## Alert Rules Summary

### Infrastructure Alerts (12 rules)

| Alert | Severity | For | Condition |
|-------|----------|-----|-----------|
| NodeHighCPU | warning | 5m | CPU > 80% |
| NodeHighMemory | warning | 5m | Memory > 85% |
| NodeDiskSpaceLow | warning | 5m | Disk > 85% |
| NodeDiskSpaceCritical | critical | 2m | Disk > 95% |
| NodeNotReady | critical | 5m | Node not ready |
| PodCrashLooping | critical | 5m | >3 restarts in 15m |
| PodOOMKilled | critical | 0m | OOMKilled detected |
| PodNotReady | warning | 5m | Pod not ready |
| PVCAlmostFull | warning | 5m | PVC > 85% |
| PVCFull | critical | 2m | PVC > 95% |
| DeploymentReplicasMismatch | warning | 5m | Desired != Available |
| StatefulSetReplicasMismatch | warning | 5m | Desired != Ready |

### Application Alerts (7 rules)

| Alert | Severity | For | Condition |
|-------|----------|-----|-----------|
| HighErrorRate | warning | 5m | Error rate > 5% |
| CriticalErrorRate | critical | 2m | Error rate > 10% |
| HighResponseTime | warning | 5m | P95 latency > 2s |
| ServiceDown | critical | 1m | Service unreachable |
| High5xxRate | warning | 5m | 5xx rate > 1% |
| High5xxErrorsIn5Min | critical | 0m | >5 5xx errors in 5m |
| High5xxErrorsIn5MinTotal | critical | 0m | >10 5xx errors total |

### SLA Alerts (6 rules)

| Alert | Severity | For | Condition |
|-------|----------|-----|-----------|
| ServiceCompletelyDown | critical | 1m | All pods down |
| AllPodsDownNodejs | critical | 1m | nodejs-catalog down |
| AllPodsDownPython | critical | 1m | python-orders down |
| AllPodsDownGo | critical | 1m | go-inventory down |
| SLABreach99 | critical | 5m | Uptime < 99% |
| SLABreach999 | warning | 5m | Uptime < 99.9% |

## Alertmanager Configuration

### Routing

```yaml
route:
  receiver: 'slack-notifications'
  group_by: ['alertname', 'severity']
  group_wait: 30s        # Wait before sending first notification
  group_interval: 5m     # Wait before sending updates
  repeat_interval: 4h    # Resend if still firing
  routes:
    - match:
        severity: critical
      repeat_interval: 1h  # More frequent for critical
```

### Slack Integration

```yaml
receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#alerts'
        send_resolved: true
        title: '{{ .Status | toUpper }}: {{ .CommonLabels.alertname }}'
        text: >-
          *Alert:* {{ .CommonLabels.alertname }}
          *Severity:* {{ .CommonLabels.severity }}
          *Description:* {{ .CommonAnnotations.description }}
```

## Alert Lifecycle

```
┌──────────────────────────────────────────────────────────────┐
│                    ALERT LIFECYCLE                            │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  INACTIVE                                                     │
│  └─▶ Condition becomes true                                  │
│                                                               │
│  PENDING                                                      │
│  └─▶ Waiting for 'for' duration                             │
│  └─▶ If condition becomes false → back to INACTIVE          │
│                                                               │
│  FIRING                                                       │
│  └─▶ Alert sent to Alertmanager                             │
│  └─▶ Notification sent to Slack                             │
│  └─▶ If condition becomes false → RESOLVED                  │
│                                                               │
│  RESOLVED                                                     │
│  └─▶ Resolution notification sent                           │
│  └─▶ Returns to INACTIVE                                    │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## Testing Alerts

### Test Service Down Alert

```bash
# Scale down service
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=0

# Wait 90 seconds for alert to fire
sleep 90

# Check alert status
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing")'

# Restore service
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=1
```

### Test High Error Rate

```bash
# Generate 5xx errors
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000 &
for i in {1..20}; do
  curl -s http://localhost:3000/api/error
done
```

### Test OOM Kill

```bash
# This will trigger OOMKilled alert
kubectl run memory-hog --image=polinux/stress \
  --limits="memory=50Mi" \
  --restart=Never \
  -- stress --vm 1 --vm-bytes 100M --vm-hang 0
```

## Runbook: Responding to Alerts

### NodeHighCPU

1. Check which pods are using CPU:
   ```bash
   kubectl top pods -A --sort-by=cpu
   ```
2. Check for runaway processes:
   ```bash
   kubectl exec -it <pod> -- top
   ```
3. Scale horizontally or vertically if needed

### PodCrashLooping

1. Check pod logs:
   ```bash
   kubectl logs <pod> -n <namespace> --previous
   ```
2. Check events:
   ```bash
   kubectl describe pod <pod> -n <namespace>
   ```
3. Common causes: OOM, missing config, dependency failure

### ServiceDown

1. Check pod status:
   ```bash
   kubectl get pods -n ecommerce-poc -l app=<service>
   ```
2. Check deployment:
   ```bash
   kubectl describe deployment <service> -n ecommerce-poc
   ```
3. Check recent changes:
   ```bash
   kubectl rollout history deployment/<service> -n ecommerce-poc
   ```
4. Rollback if needed:
   ```bash
   kubectl rollout undo deployment/<service> -n ecommerce-poc
   ```

## Silencing Alerts

During maintenance, silence alerts:

```bash
# Access Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# Open http://localhost:9093
# Click "Silences" → "New Silence"
# Set matchers and duration
```

## Adding New Alerts

Edit `k8s/prometheus/alert-rules.yaml`:

```yaml
- alert: MyNewAlert
  expr: my_metric > threshold
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "My alert summary"
    description: "Detailed description with {{ $value }}"
```

Apply changes:
```bash
kubectl apply -f k8s/prometheus/alert-rules.yaml
kubectl rollout restart deployment/prometheus -n monitoring
```
