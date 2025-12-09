# Architecture Documentation

## System Overview

This project implements a production-ready microservices architecture on AWS EKS.

## Infrastructure Layer

### AWS Resources

| Resource | Purpose | Configuration |
|----------|---------|---------------|
| EKS Cluster | Kubernetes control plane | v1.31, managed by AWS |
| EC2 Node Group | Worker nodes | t3.medium, 1-3 nodes |
| VPC | Network isolation | 10.0.0.0/16 CIDR |
| Private Subnets | Worker node placement | 2 AZs for HA |
| Public Subnets | NAT Gateway, Load Balancers | 2 AZs |
| NAT Gateway | Outbound internet for private subnets | Single NAT (cost optimization) |
| ECR | Container registry | 3 repositories |
| EBS Volumes | Persistent storage | gp3, 60GB total |

### Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Public Subnets                    Private Subnets              │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │ 10.0.1.0/24     │              │ 10.0.10.0/24    │          │
│  │ (AZ-a)          │              │ (AZ-a)          │          │
│  │                 │              │                 │          │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │          │
│  │ │ NAT Gateway │─┼──────────────┼─│ EKS Nodes   │ │          │
│  │ └─────────────┘ │              │ └─────────────┘ │          │
│  └─────────────────┘              └─────────────────┘          │
│                                                                  │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │ 10.0.2.0/24     │              │ 10.0.20.0/24    │          │
│  │ (AZ-b)          │              │ (AZ-b)          │          │
│  └─────────────────┘              └─────────────────┘          │
│                                                                  │
│  Internet Gateway ←→ Public Subnets ←→ NAT ←→ Private Subnets  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Application Layer

### Microservices

| Service | Language | Port | Purpose |
|---------|----------|------|---------|
| nodejs-catalog | Node.js | 3000 | Product catalog API |
| python-orders | Python/Flask | 5000 | Order management |
| go-inventory | Go | 8080 | Inventory tracking |

### Service Communication

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Catalog    │────▶│    Orders    │────▶│  Inventory   │
│  (Node.js)   │     │   (Python)   │     │    (Go)      │
│   :3000      │     │    :5000     │     │   :8080      │
└──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │
       └────────────────────┴────────────────────┘
                           │
                    ┌──────▼──────┐
                    │   Tempo     │
                    │  (Traces)   │
                    └─────────────┘
```

## Observability Layer

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     OBSERVABILITY STACK                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  METRICS PIPELINE                                               │
│  ┌─────────┐    ┌─────────────┐    ┌─────────┐                 │
│  │ App     │───▶│ Prometheus  │───▶│ Grafana │                 │
│  │/metrics │    │  (scrape)   │    │ (query) │                 │
│  └─────────┘    └─────────────┘    └─────────┘                 │
│                        │                                        │
│                        ▼                                        │
│                 ┌─────────────┐    ┌─────────┐                 │
│                 │Alertmanager │───▶│  Slack  │                 │
│                 └─────────────┘    └─────────┘                 │
│                                                                  │
│  LOGS PIPELINE                                                  │
│  ┌─────────┐    ┌─────────────┐    ┌─────────┐                 │
│  │ stdout  │───▶│  Promtail   │───▶│  Loki   │                 │
│  │ stderr  │    │ (DaemonSet) │    │(storage)│                 │
│  └─────────┘    └─────────────┘    └─────────┘                 │
│                                                                  │
│  TRACES PIPELINE                                                │
│  ┌─────────┐    ┌─────────────┐    ┌─────────┐                 │
│  │  OTEL   │───▶│    OTLP     │───▶│  Tempo  │                 │
│  │  SDK    │    │   (HTTP)    │    │(storage)│                 │
│  └─────────┘    └─────────────┘    └─────────┘                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Storage Configuration

| Component | PVC Size | Retention | Storage Class |
|-----------|----------|-----------|---------------|
| Prometheus | 30GB | 15 days | gp3 |
| Grafana | 10GB | N/A | gp3 |
| Loki | 10GB | 7 days | gp3 |
| Tempo | 10GB | 7 days | gp3 |

## Scaling Architecture

### Horizontal Pod Autoscaler (HPA)

Not implemented in v4 - can be added for application pods.

### Cluster Autoscaler

```
┌─────────────────────────────────────────────────────────────────┐
│                   CLUSTER AUTOSCALER FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Pod Created                                                 │
│     ↓                                                           │
│  2. Scheduler: "No node has enough resources"                   │
│     ↓                                                           │
│  3. Pod Status: Pending                                         │
│     ↓                                                           │
│  4. Cluster Autoscaler detects pending pods                     │
│     ↓                                                           │
│  5. Autoscaler: "Increase ASG desired count"                    │
│     ↓                                                           │
│  6. AWS: Launches new EC2 instance (~2 min)                     │
│     ↓                                                           │
│  7. Node joins cluster                                          │
│     ↓                                                           │
│  8. Scheduler places pod on new node                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Security Architecture

### IAM Roles

| Role | Purpose | Attached To |
|------|---------|-------------|
| EKS Cluster Role | Control plane permissions | EKS Cluster |
| Node Instance Role | Worker node permissions | EC2 Instances |
| EBS CSI Driver Role | Volume management | EBS CSI Driver |
| Cluster Autoscaler Role | ASG management | Autoscaler Pod |

### Network Security

- Worker nodes in private subnets (no public IPs)
- Outbound internet via NAT Gateway
- Security groups limit traffic between components
- Kubernetes Network Policies (not implemented in v4)

## High Availability

### Current Setup (v4)
- 2 Availability Zones
- 2 worker nodes (can scale to 3)
- Single NAT Gateway (cost optimization)
- Single replica for monitoring components

### Production Recommendations
- 3 Availability Zones
- NAT Gateway per AZ
- Multiple replicas for critical services
- Multi-region disaster recovery
