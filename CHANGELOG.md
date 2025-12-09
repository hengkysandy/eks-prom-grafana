# Changelog

All notable changes to this project will be documented in this file.

## [v4] - 2024-12-09

### Added

#### Observability Stack
- **Prometheus** (30GB persistent storage)
  - Metrics collection from all services
  - Kubelet scraping for volume statistics
  - 15-day retention
- **Grafana** (10GB persistent storage)
  - 6 pre-configured dashboards
  - Loki and Tempo data sources
- **Loki** (10GB persistent storage)
  - Centralized log aggregation
  - 7-day retention
- **Tempo** (10GB persistent storage)
  - Distributed tracing backend
  - 7-day retention
- **Promtail** (DaemonSet)
  - Log collection from all pods
- **Node Exporter** (DaemonSet)
  - Node-level metrics (CPU, memory, disk)

#### Alerting System
- **Alertmanager** with Slack integration
- **23 alert rules** in 4 groups:
  - Infrastructure alerts (12 rules)
  - Application alerts (7 rules)
  - SLA alerts (6 rules)
  - Monitoring alerts (4 rules)
- Alert routing with severity-based grouping
- 1-minute threshold for service down detection

#### Distributed Tracing
- **OpenTelemetry** instrumentation for all services:
  - Node.js: @opentelemetry/sdk-node
  - Python: opentelemetry-instrumentation-flask
  - Go: go.opentelemetry.io/otel
- Traces sent to Tempo via OTLP HTTP

#### Auto-Scaling
- **Cluster Autoscaler** v1.31.0
  - Automatic node scaling (1-3 nodes)
  - ASG tag-based discovery
  - ~2 minute scale-up time
- IAM role and policy for autoscaler

#### Kubernetes Dashboard
- Official dashboard v7.14.0
- Admin service account with cluster-admin role
- Token-based authentication

#### Grafana Dashboards
1. **Kubernetes Cluster Overview** - Node metrics, PVC usage
2. **Pod & Container Metrics** - Per-pod resources
3. **Application Performance** - HTTP metrics, latency
4. **Application Logs & Traces** - Loki logs, Tempo traces
5. **Kubernetes Components Health** - Service status
6. **SLA Report** - Uptime tracking (daily/weekly/monthly/yearly)

#### Test Suite
- `quick-test.sh` - Fast comprehensive test
- `run-all-tests.sh` - Full test suite
- `test-http-traffic.sh` - HTTP response codes
- `test-errors.sh` - Error generation
- `test-latency.sh` - Latency testing
- `test-cross-service.sh` - Distributed tracing
- `test-alert-triggers.sh` - Alert testing
- `test-pod-stress.sh` - Resource stress
- `verify-data.sh` - Data verification

#### Documentation
- Comprehensive README.md
- MONITORING.md - Monitoring setup guide
- TRACING_SUMMARY.md - Tracing implementation
- DOWNTIME_ALERT_TEST.md - Alert testing results
- docs/LEARNING_GUIDE.md - Junior DevOps guide
- docs/ARCHITECTURE.md - System architecture
- docs/ALERTING.md - Alerting documentation
- docs/RUNBOOK.md - Operations runbook
- docs/COST_OPTIMIZATION.md - Cost guide

### Changed
- Migrated from Fargate to EC2 node groups (v3)
- Updated Prometheus config with kubelet scraping
- Enhanced application deployments with tracing

### Infrastructure
- EKS Cluster v1.31
- EC2 Node Group: t3.medium (2 vCPU, 4GB RAM)
- VPC with private subnets
- NAT Gateway for outbound traffic
- EBS gp3 storage class

---

## [v3] - 2024-12-05

### Added
- EC2 node groups (migrated from Fargate)
- Persistent storage with EBS CSI driver
- Basic Prometheus and Grafana setup

### Changed
- Node type from Fargate to EC2

---

## [v2] - 2024-12-02

### Added
- Basic observability with Prometheus
- Grafana dashboards
- Fargate profiles

---

## [v1] - 2024-12-01

### Added
- Initial EKS cluster setup
- Three microservices (Node.js, Python, Go)
- Basic Terraform infrastructure
- ECR repositories
