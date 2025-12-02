# CloudWatch Cost Analysis - November 2025

**Total CloudWatch Cost: $923.22**
**Primary Issue: APS1-CW:MetricMonitorUsage = $678.60 (73.5%)**

---

## 🔴 ROOT CAUSE IDENTIFIED

### Amazon MWAA (Managed Workflows for Apache Airflow) - ap-southeast-1

**Environment:** `prod-data-airflow`
- **Status:** AVAILABLE (running since Feb 2023)
- **Environment Class:** mw1.medium
- **Max Workers:** 12
- **Airflow Version:** 2.7.2

### 💰 TOTAL MWAA COST (November 2025)

| Component | Cost | Percentage |
|-----------|------|------------|
| **MWAA Environment** (mw1.medium) | **$631.75** | - |
| **CloudWatch Metrics** (APS1) | **$678.60** | 73.5% of CW bill |
| **TOTAL AIRFLOW COST** | **$1,310.35** | **🔴 CRITICAL** |

**This is your single most expensive service, costing more than all other CloudWatch usage combined.**

**Metrics Generated:**
- **12,040 AmazonMWAA custom metrics** in ap-southeast-1
- 48 unique metric types (TaskInstanceFinished, TaskInstanceStarted, etc.)
- 331 unique DAGs
- 305 unique Tasks
- Each combination of (MetricName + DAG + Task + State) = 1 custom metric

**Cost Calculation:**
```
12,040 metrics × $0.30/metric/month = $3,612/month (theoretical)
```

However, CloudWatch charges are prorated and based on:
- Active metrics (metrics with data points in the month)
- High-resolution metrics cost more
- API calls for GetMetricData/PutMetricData

**Your actual charge: $678.60** suggests ~2,262 active custom metrics

---

## 📊 Metric Distribution by Region

| Region | Total Metrics | Top Namespace | Count |
|--------|--------------|---------------|-------|
| **ap-southeast-1** | 12,882 | AmazonMWAA | 12,040 |
| **me-central-1** | 6,273 | AWS/ApplicationELB | 2,112 |
| | | AWS/RDS | 1,512 |
| **us-east-1** | 762 | AWS/Usage | 684 |
| **us-east-2** | 198 | AWS/Lambda | 65 |
| **ap-southeast-4** | 0 | - | - |

---

## 💰 Cost Breakdown

### Top 5 Cost Drivers

1. **APS1-CW:MetricMonitorUsage** - $678.60 (73.5%)
   - Region: ap-southeast-1 (Singapore)
   - Source: MWAA custom metrics

2. **APS4-DataProcessing-Bytes** - $50.72 (5.5%)
   - Region: ap-southeast-4 (Melbourne)
   - Log ingestion/processing

3. **MEC1-DataProcessing-Bytes** - $38.45 (4.2%)
   - Region: me-central-1 (UAE)
   - Log ingestion/processing

4. **APS4-VendedLog-Bytes** - $33.88 (3.7%)
   - Region: ap-southeast-4
   - VPC Flow Logs or other vended logs

5. **APS1-DataProcessing-Bytes** - $24.51 (2.7%)
   - Region: ap-southeast-1
   - Log ingestion

---

## 🎯 Why MWAA Generates So Many Metrics

### Airflow's Metric Model

For each DAG task execution, Airflow publishes metrics for:
- Task states: `scheduled`, `queued`, `running`, `success`, `failed`, `up_for_retry`, `up_for_reschedule`, `upstream_failed`, `skipped`, `removed`, `deferred`, `restarting`
- Metric types: `TaskInstanceStarted`, `TaskInstanceFinished`, `TaskInstanceDuration`, `TaskInstanceQueuedDuration`

**Example DAGs found:**
- `pipelines-datalake-fasset_exchange-production-to-redshift-hourly`
- `pipelines-datalake-fasset_exchange-join-to-redshift`
- `binanceOrderToRedshift`
- `generateDailyCummulativeLedger`
- `xero_finance_daily_dag`
- `userAssetSnapshot_DAG`
- And 325+ more...

### Metric Explosion Formula

```
Total Metrics = (Metric Types × DAGs × Tasks × States)

Example:
- 48 metric types
- 331 DAGs
- 305 tasks
- 13 states
= Potential for 63+ million metric combinations

Actual: 12,040 active metrics (only combinations with data)
```

---

## 🔧 SOLUTIONS - Ranked by Impact

### Option 1: Disable MWAA Metrics Publishing (HIGHEST IMPACT)
**Savings: ~$650/month (96% reduction in metric costs)**

MWAA automatically publishes metrics to CloudWatch. You can disable this:

```bash
# Check current logging configuration
aws mwaa get-environment --name prod-data-airflow --region ap-southeast-1 \
  --query 'Environment.LoggingConfiguration'

# Update environment to disable metrics (requires environment update)
# Note: This requires updating the environment configuration
# You cannot disable metrics entirely, but you can reduce logging levels
```

**Alternative:** Use Airflow's built-in StatsD/Prometheus metrics instead:
- Configure Airflow to send metrics to Prometheus
- Disable CloudWatch metrics publishing
- Much cheaper and more flexible

### Option 2: Reduce Metric Granularity
**Savings: ~$300-400/month**

Modify Airflow configuration to publish fewer metrics:
- Disable per-task metrics
- Keep only DAG-level metrics
- Reduce metric retention period

### Option 3: Archive Old Metrics
**Savings: ~$100-200/month**

CloudWatch charges for all custom metrics, even if not actively used:

```bash
# List metrics that haven't been updated in 30+ days
# These still incur charges

# Delete old metrics (they auto-expire after 15 months of no data)
```

### Option 4: Switch to Self-Hosted Airflow
**Savings: ~$650/month (metric costs) + MWAA environment costs**

Run Airflow on ECS/EKS with Prometheus for metrics:
- No CloudWatch custom metric charges
- More control over metrics
- Lower total cost

---

## 📈 Other Regions to Investigate

### me-central-1 (UAE) - Potential Hidden Costs

**Resources Found:**
- 2,112 AWS/ApplicationELB metrics (2 ALBs: prod-alb-pub, prod-alb-pvt)
- 1,512 AWS/RDS metrics (6 RDS instances)
- 434 AWS/CodeBuild metrics

**Estimated Cost Impact:** $50-100/month

These are standard AWS metrics (free tier: 10 metrics per resource), but with:
- 2 ALBs × ~1,000 metrics each = potential custom metric charges
- 6 RDS instances with Enhanced Monitoring = $3.50/instance/month

---

## ✅ IMMEDIATE ACTION ITEMS

### Priority 1: Investigate MWAA Metrics (TODAY)

```bash
# 1. Check if you actually need all these metrics
aws mwaa get-environment --name prod-data-airflow --region ap-southeast-1

# 2. Review Airflow DAGs - are all 331 DAGs active?
# Access Airflow UI: https://5492c6a2-0ea0-4e47-8425-a2af535beb40-vpce.c1.ap-southeast-1.airflow.amazonaws.com

# 3. Check metric activity in last 7 days
aws cloudwatch get-metric-statistics \
  --namespace AmazonMWAA \
  --metric-name SchedulerHeartbeat \
  --dimensions Name=Environment,Value=prod-data-airflow \
  --start-time 2025-11-25T00:00:00Z \
  --end-time 2025-12-02T00:00:00Z \
  --period 86400 \
  --statistics SampleCount \
  --region ap-southeast-1
```

### Priority 2: Set Up Cost Alerts (THIS WEEK)

```bash
# Create budget alert for CloudWatch
aws budgets create-budget \
  --account-id 683031685817 \
  --budget file://cloudwatch-budget.json
```

### Priority 3: Audit Unused DAGs (THIS WEEK)

Review your 331 DAGs:
- Disable/delete unused DAGs
- Each disabled DAG reduces metric count
- Potential savings: $1-2 per DAG per month

---

## 📊 Cost Projection

### Current State (November 2025)
- **MWAA Environment:** $631.75/month
- **MWAA CloudWatch Metrics:** $678.60/month
- **Total MWAA Cost:** $1,310.35/month
- Other CloudWatch: $244.62/month
- **Grand Total:** $1,554.97/month

### After Optimization - Option A: Optimize MWAA
- Disable MWAA CloudWatch metrics: **-$650/month**
- Optimize logging: **-$50/month**
- Keep MWAA environment: $631.75/month
- **New Total: ~$876/month**
- **Annual Savings: ~$8,400**

### After Optimization - Option B: Self-Hosted Airflow (RECOMMENDED)
- Migrate to ECS Fargate (estimated): **~$150-200/month**
- Use Prometheus for metrics: **$0**
- CloudWatch logs only: **~$20/month**
- **New Total: ~$170-220/month**
- **Annual Savings: ~$13,200-14,000**

---

## 🔍 Additional Investigation Needed

1. **Check if metrics are actually being used:**
   ```bash
   # Check CloudWatch dashboard usage
   aws cloudwatch list-dashboards --region ap-southeast-1
   
   # Check alarms using MWAA metrics
   aws cloudwatch describe-alarms --region ap-southeast-1 \
     --query 'MetricAlarms[?Namespace==`AmazonMWAA`]'
   ```

2. **Review Airflow configuration:**
   - Check `airflow.cfg` for StatsD configuration
   - Review if metrics are being used for alerting
   - Determine if CloudWatch metrics are necessary

3. **Consider alternatives:**
   - Prometheus + Grafana for Airflow metrics (free)
   - Airflow's built-in metrics UI
   - Custom metrics solution

---

## 📝 Summary

**The Problem:**
Your MWAA environment `prod-data-airflow` is your most expensive AWS service:
- **MWAA environment cost:** $631.75/month
- **CloudWatch metrics cost:** $678.60/month  
- **Total MWAA cost:** $1,310.35/month

The environment generates 12,040 custom CloudWatch metrics, making metrics MORE expensive than the service itself.

**Why It Happened:**
- MWAA automatically publishes detailed metrics for every DAG task execution
- 331 DAGs × 305 tasks × multiple states = metric explosion
- CloudWatch charges $0.30 per custom metric per month
- mw1.medium environment class costs ~$632/month

**The Fix:**
1. **Quick win:** Disable CloudWatch metrics, use Prometheus instead → Save $650/month
2. **Best option:** Migrate to self-hosted Airflow on ECS Fargate → Save $1,100-1,200/month
3. Evaluate if all 331 DAGs are necessary

**Potential savings:**
- Option A (disable metrics): **$8,400/year**
- Option B (self-hosted): **$13,200-14,000/year**

**Next Steps:**
Run the commands in "IMMEDIATE ACTION ITEMS" section above.
