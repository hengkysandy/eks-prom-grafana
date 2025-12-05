# Fargate Logging Limitation

## ❌ Issue: Loki Shows No Data

**Root Cause:** AWS Fargate doesn't support DaemonSets, which is how Promtail typically collects logs.

### Why This Happens:

1. **Promtail needs DaemonSet** - Runs on every node to read `/var/log/pods`
2. **Fargate has no nodes** - Pods run in isolated compute
3. **No host access** - Can't mount `/var/log` from host

### Current Fargate Logging:

Your logs ARE being generated, but they go to:
- **CloudWatch Logs** - `/aws/eks/ecommerce-poc-eks/application`
- **Pod stdout** - Visible via `kubectl logs`

## ✅ Solutions for Fargate

### Option 1: Use CloudWatch Logs (Current Setup)
**Pros:** Already working, no changes needed
**Cons:** AWS vendor lock-in, costs money

```bash
# View logs in CloudWatch
aws logs tail /aws/eks/ecommerce-poc-eks/application --follow
```

### Option 2: Add Promtail as Sidecar
Add Promtail container to each pod deployment.

**Pros:** Works with Loki, cloud-agnostic
**Cons:** More resource usage, complex config

### Option 3: Use Grafana Cloud Agent
Lightweight agent that works on Fargate.

**Pros:** Works well, supports Loki
**Cons:** Another component to manage

### Option 4: Switch to EC2 Node Groups
Use EC2 nodes instead of Fargate.

**Pros:** Full DaemonSet support, Promtail works
**Cons:** More expensive, need to manage nodes

### Option 5: Use FluentBit Sidecar
AWS-native solution.

**Pros:** Well-documented for Fargate
**Cons:** More complex than Promtail

## 🎯 Recommended Approach

### For This PoC:
**Use CloudWatch Logs** - It's already working and you can view logs there.

### For Production (Cloud-Agnostic):
**Add Promtail Sidecar** to each deployment:

```yaml
containers:
- name: app
  image: your-app
- name: promtail
  image: grafana/promtail:2.9.3
  args:
    - -config.file=/etc/promtail/promtail.yaml
  volumeMounts:
    - name: logs
      mountPath: /var/log
    - name: promtail-config
      mountPath: /etc/promtail
volumes:
  - name: logs
    emptyDir: {}
```

## 📊 What About Tempo (Traces)?

**Tempo DOES work!** Traces are sent via HTTP/gRPC, not file-based.

Your app is already sending traces to:
```
http://tempo.monitoring.svc.cluster.local:4318/v1/traces
```

### To See Traces in Grafana:

1. Go to **Explore** → **Tempo**
2. Search by:
   - Service: `nodejs-catalog`
   - Time range: Last 15 minutes
3. Click **Run Query**

**Note:** Traces are ephemeral (stored in emptyDir), so they only last while the pod is running.

## 🔍 Viewing Logs Without Loki

### Method 1: kubectl logs
```bash
# Real-time logs
kubectl logs -n ecommerce-poc -l app=nodejs-catalog -f

# JSON formatted
kubectl logs -n ecommerce-poc -l app=nodejs-catalog | jq

# Filter errors
kubectl logs -n ecommerce-poc -l app=nodejs-catalog | jq 'select(.level=="error")'

# Show trace IDs
kubectl logs -n ecommerce-poc -l app=nodejs-catalog | jq -r '.trace_id' | grep -v null
```

### Method 2: CloudWatch Logs Insights
```sql
fields @timestamp, @message
| filter namespace = "ecommerce-poc"
| filter level = "error"
| sort @timestamp desc
| limit 20
```

### Method 3: Stern (kubectl logs on steroids)
```bash
# Install stern
brew install stern

# Tail logs from all pods
stern -n ecommerce-poc nodejs-catalog

# Filter by level
stern -n ecommerce-poc nodejs-catalog | jq 'select(.level=="error")'
```

## 💡 Quick Demo Without Loki

Since Loki doesn't work on Fargate without sidecars, let's verify the observability stack:

### 1. Metrics (AMP) ✅ WORKING
```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000

# Go to Dashboards → Microservices Observability
# See: Request rates, error rates, response times
```

### 2. Logs (kubectl) ✅ WORKING
```bash
# View logs
kubectl logs -n ecommerce-poc -l app=nodejs-catalog --tail=50

# See structured JSON with trace_id
```

### 3. Traces (Tempo) ✅ SHOULD WORK
```bash
# In Grafana Explore → Tempo
# Service: nodejs-catalog
# Run Query
```

## 🚀 Next Steps

### To Get Loki Working:

**Quick Fix (5 minutes):**
Add Promtail sidecar to nodejs-catalog deployment.

**Want me to implement this?** I can:
1. Update nodejs-catalog deployment with Promtail sidecar
2. Configure Promtail to send logs to Loki
3. Verify logs appear in Grafana

### Alternative:

**Accept the limitation** and use:
- Metrics: AMP (working)
- Logs: CloudWatch or kubectl (working)
- Traces: Tempo (should work)

This is still a valid observability stack, just with AWS CloudWatch for logs instead of Loki.

## 📝 Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Prometheus/AMP | ✅ Working | Metrics visible in Grafana |
| Loki | ❌ No data | Needs sidecar on Fargate |
| Tempo | ⚠️ Should work | Check if traces are being sent |
| Grafana | ✅ Working | Dashboards imported |
| CloudWatch Logs | ✅ Working | Alternative to Loki |

**Bottom line:** Fargate + Loki requires sidecars. For true cloud-agnostic setup, use EC2 node groups instead of Fargate.
