# Amazon Managed Prometheus (AMP) Setup Guide

Complete step-by-step guide to set up AMP integration with EKS, Prometheus, and Grafana.

## Prerequisites

- EKS cluster running with Fargate
- kubectl configured
- Helm 3.x installed
- AWS CLI configured
- Terraform (for infrastructure setup)

## Architecture Overview

```
Application Pods → Prometheus (Helm) → AMP (remote_write) → Grafana (query)
                        ↓
                   Local TSDB
                  (ephemeral)
```

## Step 1: Deploy Infrastructure with Terraform

### 1.1 Create AMP Workspace and IAM Roles

The `terraform/amp.tf` file creates:
- AMP workspace
- OIDC provider for EKS
- IAM roles for Prometheus (ingest) and Grafana (query)
- IAM policies with proper permissions

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**What gets created:**
- AMP workspace: `ws-xxxxxxxxx`
- IAM role: `ecommerce-poc-amp-ingest-role` (for Prometheus)
- IAM role: `ecommerce-poc-amp-query-role` (for Grafana)
- OIDC provider for IRSA authentication

### 1.2 Capture Outputs

```bash
terraform output amp_workspace_id
terraform output amp_remote_write_url
terraform output amp_ingest_role_arn
terraform output amp_query_role_arn
```

Save these values - you'll need them for Kubernetes configuration.

## Step 2: Fix VPC Endpoint Security Group

**Critical:** The STS VPC endpoint must allow traffic from EKS cluster.

### 2.1 Get Security Group IDs

```bash
# Get STS VPC endpoint security group
aws ec2 describe-vpc-endpoints \
  --region ap-southeast-1 \
  --filters "Name=service-name,Values=com.amazonaws.ap-southeast-1.sts" \
  --query 'VpcEndpoints[0].Groups[0].GroupId' \
  --output text

# Get EKS cluster security group
aws eks describe-cluster \
  --name ecommerce-poc-eks \
  --region ap-southeast-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text
```

### 2.2 Add Ingress Rule

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <STS_VPC_ENDPOINT_SG> \
  --protocol tcp \
  --port 443 \
  --source-group <EKS_CLUSTER_SG> \
  --region ap-southeast-1 \
  --description "Allow HTTPS from EKS cluster for STS"
```

**Why this is needed:** Prometheus pods need to call STS to assume the IAM role for AMP authentication.

## Step 3: Create Kubernetes Service Accounts

### 3.1 Create Service Account for Prometheus

```bash
kubectl create serviceaccount amp-iamproxy-ingest-service-account -n monitoring
kubectl annotate serviceaccount amp-iamproxy-ingest-service-account \
  -n monitoring \
  eks.amazonaws.com/role-arn=<AMP_INGEST_ROLE_ARN>
```

### 3.2 Create Service Account for Grafana

```bash
kubectl create serviceaccount grafana -n monitoring
kubectl annotate serviceaccount grafana \
  -n monitoring \
  eks.amazonaws.com/role-arn=<AMP_QUERY_ROLE_ARN>
```

## Step 4: Update IAM Trust Policies

**Important:** The trust policy must match the exact service account name.

### 4.1 Update Prometheus Ingest Role Trust Policy

Create `trust-policy-ingest.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:sub": "system:serviceaccount:monitoring:amp-iamproxy-ingest-service-account",
          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

Apply:
```bash
aws iam update-assume-role-policy \
  --role-name ecommerce-poc-amp-ingest-role \
  --policy-document file://trust-policy-ingest.json
```

### 4.2 Update Grafana Query Role Trust Policy

Create `trust-policy-query.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:sub": "system:serviceaccount:monitoring:grafana",
          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

Apply:
```bash
aws iam update-assume-role-policy \
  --role-name ecommerce-poc-amp-query-role \
  --policy-document file://trust-policy-query.json
```

## Step 5: Deploy Prometheus via Helm

### 5.1 Add Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 5.2 Create Helm Values File

File: `k8s/prometheus/prometheus-values.yaml`

```yaml
serviceAccounts:
  server:
    name: "amp-iamproxy-ingest-service-account"
    annotations:
      eks.amazonaws.com/role-arn: "<AMP_INGEST_ROLE_ARN>"

server:
  remoteWrite:
    - url: <AMP_REMOTE_WRITE_URL>
      sigv4:
        region: ap-southeast-1
      queue_config:
        max_samples_per_send: 1000
        max_shards: 200
        capacity: 2500
  persistentVolume:
    enabled: false
  emptyDir:
    sizeLimit: 8Gi

serverFiles:
  prometheus.yml:
    scrape_configs:
      - job_name: 'nodejs-catalog'
        static_configs:
          - targets: ['nodejs-catalog.ecommerce-poc.svc.cluster.local:3000']
      
      - job_name: 'python-orders'
        static_configs:
          - targets: ['python-orders.ecommerce-poc.svc.cluster.local:5000']
      
      - job_name: 'go-inventory'
        static_configs:
          - targets: ['go-inventory.ecommerce-poc.svc.cluster.local:8080']
      
      - job_name: 'kube-state-metrics'
        static_configs:
          - targets: ['kube-state-metrics.monitoring.svc.cluster.local:8080']

alertmanager:
  enabled: false

prometheus-node-exporter:
  enabled: false

prometheus-pushgateway:
  enabled: false

kube-state-metrics:
  enabled: false
```

### 5.3 Install Prometheus

```bash
helm install prometheus prometheus-community/prometheus \
  -n monitoring \
  -f k8s/prometheus/prometheus-values.yaml
```

### 5.4 Verify Prometheus

```bash
# Check pod status
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Should show: 2/2 Running

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -c prometheus-server --tail=50

# Look for:
# - "Starting WAL watcher" with AMP URL
# - "Done replaying WAL" (successful remote_write)
# - No errors about credentials or connectivity
```

## Step 6: Deploy Grafana with AMP Datasource

### 6.1 Apply Grafana Configuration

```bash
kubectl apply -f k8s/grafana/grafana-deployment.yaml
```

This deploys Grafana with:
- Service account with AMP query role
- AMP datasource pre-configured
- SigV4 authentication enabled

### 6.2 Verify Grafana

```bash
# Check pod status
kubectl get pods -n monitoring -l app=grafana

# Port-forward
kubectl port-forward -n monitoring svc/grafana 3001:3000

# Access: http://localhost:3001
# Username: admin
# Password: admin
```

### 6.3 Test AMP Datasource

In Grafana:
1. Go to **Configuration** → **Data Sources**
2. Click on **AMP**
3. Click **Test** button
4. Should show: "Data source is working"

Or via API:
```bash
curl -u admin:admin http://localhost:3001/api/datasources/proxy/1/api/v1/query?query=up
```

## Step 7: Import Dashboards

```bash
cd k8s/grafana
./import-dashboards.sh
```

This imports:
- Comprehensive EKS observability dashboard
- Microservices HTTP metrics dashboard
- 3 Kubernetes cluster dashboards

## Verification Checklist

### ✅ Prometheus
- [ ] Pod is 2/2 Running
- [ ] Logs show "Done replaying WAL" with AMP URL
- [ ] No credential or connectivity errors
- [ ] All scrape targets are UP

```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
curl http://localhost:9090/api/v1/targets
```

### ✅ AMP
- [ ] Workspace is Active
- [ ] Metrics are being ingested

```bash
aws amp describe-workspace \
  --workspace-id <WORKSPACE_ID> \
  --region ap-southeast-1
```

### ✅ Grafana
- [ ] Pod is 1/1 Running
- [ ] AMP datasource test passes
- [ ] Dashboards show data
- [ ] Queries return results

```bash
curl -u admin:admin \
  'http://localhost:3001/api/datasources/proxy/1/api/v1/query?query=up'
```

## Troubleshooting

### Issue: Prometheus CrashLoopBackOff

**Error:** `AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Solution:** Check IAM trust policy matches service account name exactly.

```bash
# Get service account name
kubectl get sa -n monitoring

# Check trust policy
aws iam get-role --role-name ecommerce-poc-amp-ingest-role \
  --query 'Role.AssumeRolePolicyDocument'
```

### Issue: Timeout connecting to STS

**Error:** `dial tcp 172.31.x.x:443: i/o timeout`

**Solution:** Add security group rule (Step 2.2)

```bash
# Test connectivity from pod
kubectl exec -n monitoring <prometheus-pod> -c prometheus-server -- \
  wget -T 5 -O- https://sts.ap-southeast-1.amazonaws.com
```

### Issue: Grafana can't query AMP

**Error:** `403 Forbidden` or `No data`

**Solution:** Check Grafana service account has correct IAM role annotation.

```bash
kubectl get sa grafana -n monitoring -o yaml | grep role-arn
```

## Cost Optimization

### Current Setup Costs (~$2.66/month)

- **Ingestion:** $0.10 per 10M samples = ~$1.73/month
- **Storage:** $0.03 per GB-month = ~$0.50/month
- **Queries:** $0.01 per 10M samples = ~$0.43/month

### Tips to Reduce Costs

1. **Adjust scrape interval** - Change from 15s to 30s or 60s
2. **Filter metrics** - Only send important metrics to AMP
3. **Use recording rules** - Pre-aggregate data
4. **Set retention** - Configure AMP retention period

## Next Steps

1. **Set up alerting** - Configure Alertmanager with AMP
2. **Add more scrape targets** - Monitor additional services
3. **Create custom dashboards** - Build team-specific views
4. **Implement recording rules** - Optimize query performance
5. **Set up backup** - Export important dashboards

## References

- [AWS AMP Documentation](https://docs.aws.amazon.com/prometheus/)
- [Prometheus Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)

## Support Files in This Repo

- `terraform/amp.tf` - AMP infrastructure
- `k8s/prometheus/prometheus-values.yaml` - Helm values
- `k8s/grafana/grafana-deployment.yaml` - Grafana with AMP
- `AMP_VERIFICATION.md` - Verification results
- `GRAFANA_AMP_SETUP.md` - Grafana configuration details
- `POD_RESTART_TEST.md` - Data persistence verification
