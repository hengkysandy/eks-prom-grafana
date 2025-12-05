# Changes Log

Recent updates and modifications to the e-commerce microservices PoC.

## 2025-12-05: Cloud-Agnostic Observability Stack

### Added

**Loki (Log Aggregation):**
- Deployed Loki 2.9.3 in monitoring namespace
- Configured boltdb-shipper schema with local storage
- Added Loki datasource to Grafana with trace correlation
- Implemented winston-loki in Node.js for direct log shipping
- Fargate limitation: Cannot use Promtail DaemonSet, using application-level integration

**Tempo (Distributed Tracing):**
- Deployed Tempo 2.3.1 in monitoring namespace
- Configured OTLP receivers (HTTP on 4318, gRPC on 4317)
- Added Tempo datasource to Grafana
- Implemented OpenTelemetry instrumentation in Node.js service
- Capturing 1,300+ traces with trace_id correlation in logs
- 1 hour retention with local backend storage

**Cross-Service Communication:**
- Added `/products/:id/availability` endpoint (Node.js → Go)
- Added `/products/:id/order` endpoint (Node.js → Go → Python)
- Implemented 3-tier service call chain for testing distributed tracing

**Error Testing Endpoints:**
- `/error/500` - Internal server error
- `/error/db` - Database connection failure
- `/error/timeout` - Request timeout
- `/error/crash` - Application crash
- Added to all three services for observability testing

**JSON Structured Logging:**
- Node.js: winston with trace_id, span_id, timestamp, level, message
- Python: Custom JsonFormatter with service, method, path, status_code
- Go: Custom JSON logger with timestamp, level, message, service fields

### Changed

**Prometheus Configuration:**
- Switched from sidecar proxy to native SigV4 support for AMP
- Added remote_write configuration to Amazon Managed Prometheus
- Configured queue_config: 1000 samples, 200 shards, 2500 capacity
- Changed storage from PVC to emptyDir (8Gi) for Fargate compatibility
- Disabled alertmanager, node-exporter, pushgateway, kube-state-metrics for Fargate

**Grafana Datasources:**
- Updated Prometheus datasource to use in-cluster Prometheus as default
- Added AMP as secondary datasource with SigV4 authentication
- Added Loki datasource with LogQL support
- Added Tempo datasource with trace-to-logs correlation
- Configured tracesToLogs mapping via trace_id field

**Node.js Service:**
- Removed swagger-stats (added no value to observability)
- Added OpenTelemetry auto-instrumentation
- Added winston-loki transport for direct log shipping to Loki
- Updated logging to include trace_id and span_id in all log entries
- Added cross-service HTTP calls to Go and Python services

**Python Service:**
- Rebuilt image with JSON structured logging
- Added error test endpoints
- Updated to return order details in responses
- Fixed image tagging issue (added :latest tag)

**Go Service:**
- Rebuilt image with JSON structured logging
- Added error test endpoints
- Implemented responseWriter wrapper to capture status codes
- Fixed image tagging issue (added :latest tag)

### Fixed

**AMP Integration Issues:**
- Fixed VPC endpoint security group: Added ingress rule allowing EKS cluster SG (sg-03e7ab56f5256f344) to reach STS VPC endpoint SG (sg-05b5dfaf8caa94f9e) on port 443
- Fixed IAM trust policy: Updated to match actual service account name (amp-iamproxy-ingest-service-account instead of amp-iamproxy-ingest)
- Verified Prometheus WAL replay to AMP (9.4s duration, successful)

**Image Pull Failures:**
- Fixed missing image tags in ECR for Python and Go services
- Added explicit :latest tag during docker push
- Rebuilt and pushed all images with proper tags

**Fargate Logging:**
- Identified Promtail DaemonSet limitation on Fargate (no nodes)
- Implemented winston-loki for direct log shipping from Node.js
- Documented need for application-level log integration on Fargate

### Removed

- Swagger-stats from Node.js service (unnecessary overhead)
- Old Prometheus deployment with sidecar proxy pattern
- Unused PVC configurations for Fargate compatibility

## Cost Impact

**Added Costs:**
- Loki pod: ~$7-8/month (Fargate compute)
- Tempo pod: ~$7-8/month (Fargate compute)
- Total additional: ~$14-16/month

**Cost Comparison:**
- Self-hosted observability (Loki + Tempo + Prometheus): ~$42-51/month
- AWS Managed (CloudWatch Logs + AMP): ~$876/month
- **Savings: 95% cheaper with self-hosted stack**

**Note:** Using emptyDir storage (ephemeral). For persistent storage, add ~$2/month per 20GB EBS volume.

## Architecture Decisions

### Why Loki Instead of CloudWatch Logs?

1. **Cost:** 95% cheaper for similar functionality
2. **Cloud-agnostic:** Works on any Kubernetes cluster
3. **Better integration:** Native Grafana support with LogQL
4. **Trace correlation:** Direct linking from logs to traces via trace_id

### Why Tempo Instead of AWS X-Ray?

1. **Cloud-agnostic:** OpenTelemetry standard, works anywhere
2. **Cost:** Free (only Fargate compute cost)
3. **Integration:** Native Grafana support
4. **Flexibility:** Full control over retention and storage

### Why Keep AMP?

1. **Long-term storage:** Prometheus emptyDir only keeps ~2 hours
2. **Managed service:** No maintenance overhead
3. **Durability:** Data persists across pod restarts
4. **Optional:** Can be removed for fully cloud-agnostic setup

## Known Limitations

### Fargate-Specific

1. **No DaemonSets:** Cannot use Promtail, node-exporter, or other DaemonSet-based tools
2. **Slower startup:** Pods take 30-60 seconds to start vs 5-10 seconds on EC2 nodes
3. **No node-level metrics:** Cannot collect node-level metrics without EC2 nodes
4. **Storage:** emptyDir only, PVCs require additional configuration

### Observability Stack

1. **Ephemeral storage:** Data lost on pod restart (emptyDir)
2. **Limited retention:** Tempo 1 hour, Prometheus ~2 hours
3. **Single service tracing:** Only Node.js has OpenTelemetry instrumentation
4. **No distributed tracing:** Python and Go services need OpenTelemetry SDKs

### Cloud-Agnostic Considerations

1. **Fargate is AWS-only:** For true cloud-agnostic, use EC2 nodes or equivalent VMs
2. **AMP is AWS-only:** For cloud-agnostic, use only in-cluster Prometheus
3. **ECR is AWS-only:** For cloud-agnostic, use Harbor or other registry

## Next Steps

### For Production

1. **Add Persistent Storage:**
   - Configure PersistentVolumeClaims for Loki, Tempo, Grafana
   - Use S3 backend for Loki and Tempo
   - Increase retention periods

2. **Complete Distributed Tracing:**
   - Add OpenTelemetry to Python service
   - Add OpenTelemetry to Go service
   - Implement trace context propagation via HTTP headers

3. **Switch to EC2 Nodes:**
   - Better for cloud-agnostic architecture
   - Allows DaemonSets (Promtail, node-exporter)
   - More cost-effective for always-on services
   - Easier migration to other clouds

4. **Add Alerting:**
   - Configure Prometheus AlertManager
   - Create alert rules for errors, latency, downtime
   - Integrate with notification channels

5. **Secure Access:**
   - Enable authentication on Grafana
   - Use TLS for all connections
   - Implement RBAC for datasources

## Testing Performed

### Observability Testing (2025-12-05)

**Metrics:**
- ✅ Prometheus scraping all 3 services
- ✅ Metrics flowing to AMP via remote_write
- ✅ Grafana querying both Prometheus and AMP
- ✅ Custom dashboards showing request rate, error rate, response time

**Logs:**
- ✅ JSON structured logging in all services
- ✅ Winston-loki shipping logs from Node.js to Loki
- ✅ Grafana querying logs via LogQL
- ✅ Trace correlation working (trace_id in logs)

**Traces:**
- ✅ OpenTelemetry capturing traces from Node.js
- ✅ 1,300+ traces stored in Tempo
- ✅ Grafana searching traces by service, status code, duration
- ✅ Error traces captured (HTTP 500, 503, 504)
- ✅ Trace-to-logs correlation working

**Cross-Service Calls:**
- ✅ Node.js → Go (availability check)
- ✅ Node.js → Go → Python (order creation)
- ✅ Error propagation across services
- ⚠️ Only Node.js spans captured (Python/Go need instrumentation)

**Load Testing:**
- ✅ Generated 90+ requests with errors
- ✅ Generated 25+ cross-service calls
- ✅ Verified metrics, logs, and traces captured correctly

## Documentation Updates

- ✅ Updated README.md with cloud-agnostic architecture
- ✅ Created OBSERVABILITY.md with comprehensive guide
- ✅ Updated cost breakdown with observability stack
- ✅ Added data flow diagrams for logs, metrics, traces
- ✅ Documented Fargate limitations and workarounds
- ✅ Added cloud-agnostic recommendations

## References

- [Prometheus Remote Write](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write)
- [Loki on Kubernetes](https://grafana.com/docs/loki/latest/installation/kubernetes/)
- [Tempo Configuration](https://grafana.com/docs/tempo/latest/configuration/)
- [OpenTelemetry Node.js](https://opentelemetry.io/docs/instrumentation/js/)
- [Winston Loki Transport](https://github.com/JaniAnttonen/winston-loki)
- [Grafana Trace to Logs](https://grafana.com/docs/grafana/latest/datasources/tempo/#trace-to-logs)
