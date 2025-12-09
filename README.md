# E-Commerce Microservices PoC on AWS EKS

Complete proof-of-concept for deploying a 3-microservice e-commerce application to AWS EKS with **EC2 nodes** and **cloud-agnostic observability stack** (Prometheus, Loki, Tempo, Grafana) with persistent storage.

## 🚀 Quick Links

- **[Getting Started](GETTING_STARTED.md)** - Step-by-step deployment guide
- **[Deployment Summary](DEPLOYMENT_SUMMARY.md)** - Current state and resources
- **[Quick Reference](QUICK_REFERENCE.md)** - Common commands
- **[Observability Guide](OBSERVABILITY.md)** - Logs, metrics, and traces

## Architecture

- **Region**: ap-southeast-1
- **Compute**: EKS with EC2 nodes (t3.medium, 2 nodes)
- **Services**: 3 microservices (Node.js, Python, Go) with cross-service calls
- **Observability**: Cloud-agnostic stack with persistent storage
  - **Metrics**: Prometheus (30GB PVC, 15 days retention)
  - **Logs**: Loki (10GB PVC, 7 days retention)
  - **Traces**: Tempo (10GB PVC, 7 days retention)
  - **Visualization**: Grafana (10GB PVC)
- **Registry**: Amazon ECR
- **Storage**: EBS gp3 volumes via CSI driver

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User Request                                │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│  Node.js Catalog → Go Inventory → Python Orders                     │
│  (Cross-service calls with OpenTelemetry tracing)                  │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Observability Stack                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  Prometheus  │  │     Loki     │  │    Tempo     │             │
│  │   (30GB)     │  │    (10GB)    │  │   (10GB)     │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│         ↓                  ↓                  ↓                     │
│  ┌─────────────────────────────────────────────────────┐           │
│  │              Grafana (10GB)                         │           │
│  └─────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
.
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # EKS, EC2 nodes, ECR, networking
│   ├── variables.tf       # Configuration variables
│   └── outputs.tf         # Output values
├── k8s/                   # Kubernetes manifests
│   ├── namespace.yaml     # Namespaces
│   ├── storage-class.yaml # EBS gp3 StorageClass
│   ├── *-deployment.yaml  # Service deployments
│   ├── prometheus/        # Prometheus with PVC
│   ├── grafana/           # Grafana with PVC
│   ├── loki/              # Loki with PVC
│   ├── tempo/             # Tempo with PVC
│   └── kustomization.yaml
├── apps/                  # Application code
│   ├── nodejs/            # Catalog service
│   ├── python/            # Orders service
│   └── go/                # Inventory service
└── README.md
```

## Prerequisites

- AWS CLI v2.x configured
- Docker Desktop running
- kubectl installed
- Terraform >= 1.0
- Region: ap-southeast-1

## Deployment Steps

### 1. Create Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

Expected resources:
- EKS Cluster with 2 EC2 nodes (t3.medium)
- EBS CSI Driver addon
- 3 ECR repositories
- NAT Gateway, subnets, route tables

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name ecommerce-poc-eks
kubectl get nodes  # Should show 2 nodes
```

### 3. Build and Push Images

```bash
cd apps
./build-and-push.sh
```

### 4. Deploy Kubernetes Resources

```bash
cd k8s
kubectl apply -k .
```

### 5. Verify Deployment

```bash
# Check pods
kubectl get pods -n ecommerce-poc
kubectl get pods -n monitoring

# Check PVCs
kubectl get pvc -n monitoring
```

### 6. Access Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
# Open http://localhost:3001 (admin/admin)
```

## Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| EKS Control Plane | ~$73 |
| EC2 Nodes (2x t3.medium) | ~$60 |
| NAT Gateway | ~$32 |
| EBS Volumes (60GB total) | ~$6 |
| **Total** | **~$171/month** |

## Cleanup

```bash
# Delete Kubernetes resources
cd k8s
kubectl delete -k .

# Wait for PVCs to be deleted
kubectl get pvc -n monitoring

# Destroy infrastructure
cd ../terraform
terraform destroy -auto-approve
```

## Key Differences from Fargate Version

| Aspect | Fargate (v2) | EC2 Nodes (v3) |
|--------|--------------|----------------|
| Compute | Serverless pods | EC2 instances |
| Storage | emptyDir only | EBS persistent volumes |
| DaemonSets | Not supported | Supported |
| Cost | Pay per pod | Pay per node |
| Startup | 30-60s | 5-10s |
| Cloud-agnostic | AWS-only | Portable |

## Namespaces

- `ecommerce-poc`: Application microservices
- `monitoring`: Prometheus, Grafana, Loki, Tempo

## Persistent Volumes

| Component | Size | Retention |
|-----------|------|-----------|
| Prometheus | 30GB | 15 days |
| Grafana | 10GB | N/A |
| Loki | 10GB | 7 days |
| Tempo | 10GB | 7 days |

## Cloud-Agnostic Benefits

This setup can be migrated to:
- **GCP GKE**: Change StorageClass to pd-standard
- **Azure AKS**: Change StorageClass to managed-premium
- **On-premises**: Use local-path or NFS StorageClass

Only Terraform and StorageClass need changes; all K8s manifests remain the same.
