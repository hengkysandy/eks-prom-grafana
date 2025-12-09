# OpenTelemetry Tracing Implementation

## Overview

All three microservices now send distributed traces to Tempo using OpenTelemetry instrumentation.

## Implementation Details

### Node.js (Catalog Service)
- **Library**: `@opentelemetry/sdk-node`, `@opentelemetry/auto-instrumentations-node`
- **Exporter**: `@opentelemetry/exporter-trace-otlp-http`
- **Service Name**: `nodejs-catalog`
- **Auto-instrumentation**: HTTP, Express, Fetch API
- **File**: `apps/nodejs/tracing.js` (loaded before app starts)

### Python (Orders Service)
- **Library**: `opentelemetry-sdk`, `opentelemetry-instrumentation-flask`
- **Exporter**: `opentelemetry-exporter-otlp-proto-http`
- **Service Name**: `python-orders`
- **Auto-instrumentation**: Flask HTTP requests
- **Configuration**: Resource with `SERVICE_NAME` attribute

### Go (Inventory Service)
- **Library**: `go.opentelemetry.io/otel/sdk`, `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp`
- **Exporter**: `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp`
- **Service Name**: `go-inventory`
- **Instrumentation**: Manual wrapping with `otelhttp.NewHandler`
- **Configuration**: Resource with semantic conventions

## Tempo Configuration

- **Endpoint**: `http://tempo.monitoring.svc.cluster.local:4318/v1/traces`
- **Protocol**: OTLP over HTTP
- **Storage**: 10GB persistent volume (EBS gp3)
- **Retention**: 168 hours (7 days)

## Trace Flow

```
User Request
     ↓
nodejs-catalog (span: GET /products/1/order)
     ↓
go-inventory (span: GET /inventory/1)
     ↓
python-orders (span: POST /orders)
```

Each service creates spans that are correlated by trace ID, allowing you to see the complete request flow across all microservices.

## Viewing Traces in Grafana

### Method 1: Service Search
1. Open http://localhost:3001
2. Navigate to **Explore** → Select **Tempo** datasource
3. Use **Search** tab → Select service name from dropdown
4. Click **Run Query**

### Method 2: TraceQL Queries
```
# All traces from Node.js service
{ service.name="nodejs-catalog" }

# All traces from Go service
{ service.name="go-inventory" }

# All traces from Python service
{ service.name="python-orders" }

# Traces with errors
{ status=error }

# Traces longer than 100ms
{ duration > 100ms }
```

### Method 3: Logs to Traces
1. In **Explore**, select **Loki** datasource
2. Query logs: `{container="nodejs-catalog"}`
3. Click on any log line
4. Click **Tempo** button to jump to related trace

## Trace Attributes

Each span includes:
- **service.name**: Service identifier
- **http.method**: HTTP method (GET, POST, etc.)
- **http.url**: Request URL
- **http.status_code**: Response status
- **http.route**: Route pattern
- **span.kind**: CLIENT or SERVER

## Benefits

1. **End-to-end visibility**: See complete request flow across all services
2. **Performance analysis**: Identify slow services and bottlenecks
3. **Error tracking**: Trace errors through the entire call chain
4. **Dependency mapping**: Understand service relationships
5. **Root cause analysis**: Quickly identify which service caused an issue

## Testing Traces

Generate test traffic:
```bash
# Port forward to Node.js service
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000

# Generate cross-service calls
curl http://localhost:3000/products/1/availability
curl -X POST http://localhost:3000/products/1/order \
  -H "Content-Type: application/json" \
  -d '{"quantity":1}'
```

Verify traces in Tempo:
```bash
# Port forward to Tempo
kubectl port-forward -n monitoring svc/tempo 3200:3200

# Check services
curl http://localhost:3200/api/search/tag/service.name/values
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Pods                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Node.js    │  │      Go      │  │    Python    │     │
│  │   (OTLP)     │  │   (OTLP)     │  │   (OTLP)     │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
└─────────┼──────────────────┼──────────────────┼────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             ↓
                    ┌────────────────┐
                    │  Tempo Service │
                    │   (Port 4318)  │
                    └────────┬───────┘
                             ↓
                    ┌────────────────┐
                    │  Tempo Storage │
                    │   (10GB PVC)   │
                    └────────────────┘
                             ↑
                    ┌────────┴───────┐
                    │    Grafana     │
                    │  (Query/View)  │
                    └────────────────┘
```

## Cloud-Agnostic

This tracing setup works on any Kubernetes cluster:
- **AWS EKS**: Current implementation
- **GCP GKE**: No changes needed
- **Azure AKS**: No changes needed
- **On-premises**: No changes needed

Only the persistent volume StorageClass needs adjustment for different cloud providers.
