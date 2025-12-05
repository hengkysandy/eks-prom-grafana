# Amazon Managed Prometheus Migration

## Summary

Successfully migrated from self-hosted Prometheus to Amazon Managed Prometheus (AMP) + OSS Grafana.

## What Was Changed

### Deleted
- ❌ OSS Prometheus deployment (with emptyDir storage)
- ❌ OSS Grafana deployment (with emptyDir storage)
- ❌ Old Prometheus ConfigMap

### Created

**AWS Resources (Terraform):**
- ✅ Amazon Managed Prometheus workspace: `ws-0add6a78-6f0f-4adc-8e17-7c05be26eb5b`
- ✅ IAM role for AMP ingestion: `ecommerce-poc-amp-ingest-role`
- ✅ IAM role for AMP querying: `ecommerce-poc-amp-query-role`
- ✅ OIDC provider for IRSA (imported existing)

**Kubernetes Resources:**
- ✅ Prometheus agent (scrapes metrics, sends to AMP via remote_write)
- ✅ Grafana with AMP datasource (queries AMP with SigV4 auth)
- ✅ ServiceAccounts with IRSA annotations
- ✅ ConfigMap for AMP datasource

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EKS Cluster (Fargate)                     │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         ecommerce-poc namespace                      │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │  │
│  │  │ Node.js  │  │  Python  │  │    Go    │          │  │
│  │  │ :3000    │  │  :5000   │  │  :8080   │          │  │
│  │  │/metrics  │  │ /metrics │  │ /metrics │          │  │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘          │  │
│  └───────┼─────────────┼─────────────┼─────────────────┘  │
│          │             │             │                     │
│          │ Scrapes every 15s         │                     │
│          └─────────────┼─────────────┘                     │
│                        ▼                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         monitoring namespace                         │  │
│  │                                                      │  │
│  │  ┌────────────────┐    ┌─────────────────┐         │  │
│  │  │  Prometheus    │    │kube-state-metrics│        │  │
│  │  │  Agent         │◄───│  :8080          │         │  │
│  │  │  (Scraper)     │    └─────────────────┘         │  │
│  │  └───────┬────────┘                                 │  │
│  │          │ remote_write (SigV4)                     │  │
│  │          │                                          │  │
│  │  ┌───────▼────────┐                                 │  │
│  │  │    Grafana     │                                 │  │
│  │  │    :3000       │                                 │  │
│  │  │  (Query AMP)   │                                 │  │
│  │  └────────────────┘                                 │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        │
                        │ SigV4 Auth (IRSA)
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Amazon Managed Prometheus (AMP)                 │
│                                                              │
│  - Auto-scaling                                              │
│  - High availability                                         │
│  - Managed storage                                           │
│  - No data loss                                              │
└─────────────────────────────────────────────────────────────┘
```

## How It Works

### Metrics Ingestion
1. Prometheus agent scrapes metrics from microservices every 15s
2. Agent uses `remote_write` to send metrics to AMP
3. Authentication via AWS SigV4 (IRSA)
4. AMP stores metrics with auto-scaling and HA

### Metrics Querying
1. Grafana queries AMP using Prometheus API
2. Authentication via AWS SigV4 (IRSA)
3. Grafana renders dashboards from AMP data

### IAM Roles for Service Accounts (IRSA)
- Prometheus ServiceAccount → `amp-iamproxy-ingest` → IAM role with RemoteWriteAccess
- Grafana ServiceAccount → `grafana` → IAM role with QueryAccess

## Cost Comparison

### Before (OSS Prometheus)
```
Prometheus pod (Fargate):     $10/month
Grafana pod (Fargate):        $10/month
Storage (emptyDir):           $0
Risk: Data loss on restart    HIGH
─────────────────────────────────────
Total:                        $20/month
```

### After (AMP + OSS Grafana)
```
AMP Ingestion:                $1.41/month
AMP Storage (1,175 GB):       $35.25/month
AMP Queries:                  $4.70/month
Grafana pod (Fargate):        $10/month
Risk: Data loss               NONE
─────────────────────────────────────
Total:                        $51/month
```

**Difference:** +$31/month for:
- ✅ Auto-scaling
- ✅ High availability
- ✅ No data loss
- ✅ Managed service
- ✅ Peace of mind

## Files Changed

### Terraform
- `terraform/amp.tf` - NEW: AMP workspace and IAM roles
- `terraform/main.tf` - UPDATED: Added OIDC provider
- `terraform/outputs.tf` - UPDATED: Added AMP outputs

### Kubernetes
- `k8s/prometheus/prometheus-amp-agent.yaml` - NEW: Prometheus agent with remote_write
- `k8s/grafana/grafana-amp.yaml` - NEW: Grafana with AMP datasource
- `k8s/prometheus/prometheus-deployment.yaml` - DELETED (old OSS Prometheus)
- `k8s/grafana/grafana-deployment.yaml` - DELETED (old OSS Grafana)

## Access

### Grafana
```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```
Open: http://localhost:3001
Login: admin / admin

### Prometheus Agent (for debugging)
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```
Open: http://localhost:9090

## Verification

### Check Prometheus is sending to AMP
```bash
kubectl logs -n monitoring deployment/prometheus | grep remote_write
```

### Check Grafana datasource
1. Open Grafana
2. Go to Configuration → Data Sources
3. Click on "AMP"
4. Click "Save & Test"
5. Should see "Data source is working"

### Query metrics
In Grafana Explore:
```promql
up
http_requests_total
kube_pod_info
```

## Troubleshooting

### Prometheus not sending to AMP
```bash
# Check logs
kubectl logs -n monitoring deployment/prometheus

# Check IAM role
kubectl describe sa amp-iamproxy-ingest -n monitoring

# Verify remote_write config
kubectl get configmap prometheus-config -n monitoring -o yaml
```

### Grafana can't query AMP
```bash
# Check logs
kubectl logs -n monitoring deployment/grafana

# Check IAM role
kubectl describe sa grafana -n monitoring

# Test from pod
kubectl exec -n monitoring deployment/grafana -- \
  curl -v https://aps-workspaces.ap-southeast-1.amazonaws.com/workspaces/ws-0add6a78-6f0f-4adc-8e17-7c05be26eb5b/api/v1/query?query=up
```

### No metrics showing
```bash
# Check if Prometheus is scraping
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/targets

# Check if services are exposing metrics
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000
curl http://localhost:3000/metrics
```

## Rollback

If you need to rollback to OSS Prometheus:

```bash
# Delete AMP resources
kubectl delete -f k8s/prometheus/prometheus-amp-agent.yaml
kubectl delete -f k8s/grafana/grafana-amp.yaml

# Deploy old OSS Prometheus
kubectl apply -f k8s/prometheus/prometheus-deployment.yaml
kubectl apply -f k8s/grafana/grafana-deployment.yaml

# Destroy AMP in Terraform
cd terraform
terraform destroy -target=aws_prometheus_workspace.main
terraform destroy -target=aws_iam_role.amp_ingest
terraform destroy -target=aws_iam_role.amp_query
```

## Next Steps

1. ✅ Import Grafana dashboards
2. ✅ Run load test to verify metrics collection
3. ⬜ Set up alerting (Prometheus Alertmanager → SNS)
4. ⬜ Add more scrape targets as needed
5. ⬜ Configure retention policies in AMP
6. ⬜ Set up CloudWatch alarms for AMP costs

## Notes

- Grafana uses emptyDir (dashboards lost on restart)
- To persist dashboards: Store as ConfigMaps or use EFS
- Fargate doesn't support EBS PVCs
- AMP has 150-day retention by default
- Prometheus agent keeps 1h local retention
