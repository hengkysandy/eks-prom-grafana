# Grafana Viewing Guide - Loki & Tempo

## ✅ Grafana is Running

**URL:** http://localhost:3001
- Username: `admin`
- Password: `admin`

## 📊 Imported Dashboards

1. **Microservices Observability** - Metrics, Logs & Traces
2. **EKS Cluster Complete Observability** - Full cluster view
3. **Microservices HTTP Metrics** - Rate-based metrics
4. **Kubernetes Cluster Monitoring** (ID: 3119)
5. **Kubernetes Deployment Metrics** (ID: 8588)
6. **Kubernetes Views Pods** (ID: 15760)

## 🔍 How to View Logs in Loki

### Method 1: Explore Tab
1. Click **Explore** (compass icon) in left sidebar
2. Select **Loki** from datasource dropdown
3. Try these queries:

**All logs from ecommerce namespace:**
```logql
{namespace="ecommerce-poc"}
```

**Only error logs:**
```logql
{namespace="ecommerce-poc"} |~ "(?i)error|exception"
```

**Logs from specific service:**
```logql
{namespace="ecommerce-poc", app="nodejs-catalog"}
```

**Parse JSON and filter by level:**
```logql
{namespace="ecommerce-poc"} | json | level="error"
```

**Show trace IDs:**
```logql
{namespace="ecommerce-poc"} | json | trace_id != ""
```

### Method 2: Dashboard
1. Go to **Dashboards** → **Microservices Observability**
2. Scroll down to **Application Logs** panel
3. See real-time log stream

## 🔗 How to View Traces in Tempo

### Method 1: Explore Tab
1. Click **Explore** (compass icon)
2. Select **Tempo** from datasource dropdown
3. Search options:

**By Service Name:**
- Service: `nodejs-catalog`
- Click **Run Query**

**By Trace ID:**
- Copy a trace_id from logs (e.g., `ee3572695ce5c9931cf6815c17ef2eaf`)
- Paste in **Trace ID** field
- Click **Run Query**

**By Duration:**
- Min Duration: `100ms`
- Shows slow requests

**By Status:**
- Status: `error`
- Shows failed requests

### Method 2: From Logs to Traces
1. In **Loki** query, find a log with `trace_id`
2. Click on the log line
3. Look for **Tempo** link
4. Click to jump directly to the trace

## 📈 What You Should See

### In Loki (Logs):
```json
{
  "level": "info",
  "message": "HTTP Request",
  "method": "GET",
  "path": "/products",
  "statusCode": 200,
  "duration": 0.001,
  "trace_id": "ee3572695ce5c9931cf6815c17ef2eaf",
  "span_id": "a1e215e77b38f49e",
  "service": "nodejs-catalog"
}
```

### In Tempo (Traces):
- **Service:** nodejs-catalog
- **Operation:** GET /products
- **Duration:** 1-5ms
- **Spans:** HTTP request → Application logic
- **Tags:** method, path, status_code

### In Metrics (AMP):
- Request rate: ~3 req/s
- Error rate: ~1 error/s (from test)
- Response time: <10ms

## 🧪 Generate More Data

### Run Error Tests
```bash
cd /Users/hengky/workspace/poc-kiro/k8s
./test-errors.sh
```

Then in Grafana:
1. **Loki** - Search for `level="error"`
2. **Tempo** - Filter by `status=error`
3. **Metrics** - See `http_errors_total` spike

### Generate Load
```bash
./load-test.sh 60
```

Watch in real-time:
- Logs flowing in Loki
- Traces appearing in Tempo
- Metrics updating in dashboards

## 🎯 Example Queries

### Loki - Find Slow Requests
```logql
{namespace="ecommerce-poc"} | json | duration > 0.1
```

### Loki - Count Errors per Minute
```logql
sum(count_over_time({namespace="ecommerce-poc"} |~ "error" [1m])) by (app)
```

### Loki - Extract Trace IDs
```logql
{namespace="ecommerce-poc"} | json | trace_id != "" | line_format "{{.trace_id}}"
```

### Tempo - Service Map
1. Go to **Explore** → **Tempo**
2. Click **Service Graph** tab
3. See service dependencies

## 🔗 Correlation Flow

**The Power of Unified Observability:**

1. **Start with Metrics** (AMP)
   - See error rate spike
   - Click on time range

2. **Jump to Logs** (Loki)
   - See error messages
   - Find trace_id in logs

3. **View Trace** (Tempo)
   - Click trace_id link
   - See full request flow
   - Identify bottleneck

## 💡 Tips

### Loki Tips:
- Use `| json` to parse JSON logs
- Use `|~` for regex matching
- Use `!=` to filter out values
- Click on log lines to see details

### Tempo Tips:
- Traces are retained for 1 hour (current config)
- Use service name for broad search
- Use trace_id for specific request
- Check span attributes for details

### Dashboard Tips:
- Use time range picker (top right)
- Click on graph to zoom in
- Use variables to filter by service
- Refresh rate: 10s (auto-refresh)

## 🐛 Troubleshooting

### No logs in Loki?
```bash
# Check Loki is ready
kubectl get pods -n monitoring -l app=loki

# Wait 30 seconds for ingester to be ready
# Then refresh Grafana
```

### No traces in Tempo?
```bash
# Check Tempo is running
kubectl get pods -n monitoring -l app=tempo

# Verify OTLP endpoint
kubectl port-forward -n monitoring svc/tempo 4318:4318
curl http://localhost:4318/v1/traces
```

### Datasources not working?
1. Go to **Configuration** → **Data Sources**
2. Click on each datasource
3. Click **Test** button
4. Should show "Data source is working"

## 🎉 You're All Set!

Your observability stack is ready:
- ✅ Metrics in AMP
- ✅ Logs in Loki
- ✅ Traces in Tempo
- ✅ All visible in Grafana

Enjoy exploring your microservices! 🚀
