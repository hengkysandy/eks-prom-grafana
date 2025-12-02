# Grafana → AMP Integration

## ✅ Status: WORKING

Grafana is now querying Amazon Managed Prometheus (AMP) directly instead of local Prometheus.

## Configuration

### Datasource Settings
- **Name:** AMP
- **Type:** Prometheus
- **URL:** `https://aps-workspaces.ap-southeast-1.amazonaws.com/workspaces/ws-0add6a78-6f0f-4adc-8e17-7c05be26eb5b`
- **Authentication:** SigV4 (IAM Roles for Service Accounts)
- **Region:** ap-southeast-1
- **Default:** Yes

### Service Account
- **Name:** `grafana`
- **Namespace:** `monitoring`
- **IAM Role:** `arn:aws:iam::683031685817:role/ecommerce-poc-amp-query-role`

### Environment Variables
```yaml
- name: GF_AUTH_SIGV4_AUTH_ENABLED
  value: "true"
```

## Verification

### Test Query Results
```bash
# Query: up
Status: success
Results:
  - nodejs-catalog: 1
  - go-inventory: 1
  - python-orders: 1
  - kube-state-metrics: 1

# Query: http_requests_total
Status: success
Results:
  - go-inventory (GET): 1025
  - nodejs-catalog (GET): 3421
  - go-inventory (GET): 3416

# Query: rate(http_requests_total[1m])
Status: success
```

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────┐
│ User Browser                                                 │
│   │                                                          │
│   │ HTTP                                                     │
│   ▼                                                          │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Grafana Pod (monitoring namespace)                      │ │
│ │ - Service Account: grafana                              │ │
│ │ - IAM Role: ecommerce-poc-amp-query-role               │ │
│ │ - SigV4 Auth Enabled                                    │ │
│ └─────────────────────────────────────────────────────────┘ │
│                           │                                  │
│                           │ HTTPS + SigV4                    │
│                           ▼                                  │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ STS VPC Endpoint                                        │ │
│ │ - Validates OIDC token                                  │ │
│ │ - Returns temporary credentials                         │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ PromQL queries
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Amazon Managed Prometheus (AMP)                             │
│ - Workspace: ws-0add6a78-6f0f-4adc-8e17-7c05be26eb5b       │
│ - Receives queries from Grafana                             │
│ - Returns time-series data                                  │
└─────────────────────────────────────────────────────────────┘
```

## Complete Data Flow

```
Application Pods → Prometheus (scrape) → AMP (remote_write) → Grafana (query) → User
```

1. **Prometheus** scrapes metrics from application pods every 15s
2. **Prometheus** sends metrics to AMP via remote_write (SigV4 auth)
3. **Grafana** queries AMP directly (SigV4 auth)
4. **User** views dashboards in browser

## Benefits

✅ **Persistent Storage** - Metrics survive Prometheus pod restarts
✅ **Scalable** - AMP handles storage and query load
✅ **Managed** - AWS handles backups, HA, scaling
✅ **Cost-Effective** - Pay only for what you use (~$2-3/month for this PoC)

## Files Updated

1. **k8s/grafana/grafana-deployment.yaml** - Updated datasource config and added SigV4 env var
2. **k8s/grafana/grafana-datasource-amp.yaml** - Standalone AMP datasource config

## Access Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

Open: http://localhost:3001
- Username: `admin`
- Password: `admin`

## Troubleshooting

### Check datasource configuration
```bash
kubectl get configmap grafana-datasources -n monitoring -o yaml
```

### Test datasource from Grafana API
```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000 &
curl -u admin:admin http://localhost:3001/api/datasources
```

### Check Grafana logs
```bash
kubectl logs -n monitoring -l app=grafana --tail=50
```

### Verify IAM role
```bash
kubectl get sa grafana -n monitoring -o yaml | grep role-arn
```

## Cost Implications

### Query Costs
- **Rate:** $0.01 per 10 million samples queried
- **Typical dashboard:** ~100 queries/minute = ~4.3M queries/month
- **Estimated cost:** ~$0.43/month for queries

### Total AMP Cost (Ingestion + Storage + Queries)
- **Ingestion:** ~$1.73/month
- **Storage:** ~$0.50/month
- **Queries:** ~$0.43/month
- **Total:** ~$2.66/month

Much cheaper than running persistent storage for Prometheus!
