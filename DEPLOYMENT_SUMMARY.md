# Deployment Summary

## Current State

This document summarizes the infrastructure and applications for the EC2-based EKS deployment.

## Infrastructure (Terraform)

### AWS Resources

**EKS Cluster:**
- Name: `ecommerce-poc-eks`
- Version: 1.31
- Region: ap-southeast-1
- Compute: EC2 Node Group (2x t3.medium)

**EC2 Node Group:**
- Instance Type: t3.medium
- Desired: 2 nodes
- Min: 1 node
- Max: 3 nodes
- Capacity: ON_DEMAND

**Networking:**
- VPC: Existing VPC (vpc-04440292fc58c6a74)
- Private Subnets: 3 subnets across 3 AZs
- NAT Gateway: 1 NAT Gateway with Elastic IP
- Route Tables: Private route table with NAT Gateway

**Storage:**
- EBS CSI Driver addon installed
- StorageClass: ebs-gp3 (default)
- Volume Type: gp3

**ECR Repositories:**
- ecommerce-nodejs-catalog
- ecommerce-python-orders
- ecommerce-go-inventory

**IAM Roles:**
- EKS Cluster Role
- EC2 Node Role (with EBS CSI policy)
- EBS CSI Driver Role (IRSA)

## Kubernetes Resources

### Namespaces

- `ecommerce-poc`: Application microservices
- `monitoring`: Observability stack

### Application Pods (namespace: ecommerce-poc)

| Service | Image | Port | Replicas |
|---------|-------|------|----------|
| nodejs-catalog | ecommerce-nodejs-catalog:latest | 3000 | 1 |
| python-orders | ecommerce-python-orders:latest | 5000 | 1 |
| go-inventory | ecommerce-go-inventory:latest | 8080 | 1 |
| traffic-generator | busybox | - | 1 |

### Monitoring Pods (namespace: monitoring)

| Service | Image | Port | PVC Size |
|---------|-------|------|----------|
| prometheus | prom/prometheus:v2.48.0 | 9090 | 30Gi |
| grafana | grafana/grafana:10.2.0 | 3000 | 10Gi |
| loki | grafana/loki:2.9.3 | 3100 | 10Gi |
| tempo | grafana/tempo:2.3.1 | 3200 | 10Gi |
| kube-state-metrics | kube-state-metrics:v2.10.1 | 8080 | - |

### Persistent Volume Claims

| Name | Namespace | Size | StorageClass |
|------|-----------|------|--------------|
| prometheus-data | monitoring | 30Gi | ebs-gp3 |
| grafana-data | monitoring | 10Gi | ebs-gp3 |
| loki-data | monitoring | 10Gi | ebs-gp3 |
| tempo-data | monitoring | 10Gi | ebs-gp3 |

**Total Storage: 60GB**

## Data Retention

| Component | Retention |
|-----------|-----------|
| Prometheus | 15 days |
| Loki | 7 days |
| Tempo | 7 days |
| Grafana | Persistent |

## Access Points

### Port-Forward Commands

```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Tempo
kubectl port-forward -n monitoring svc/tempo 3200:3200

# Application Services
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000
kubectl port-forward -n ecommerce-poc svc/python-orders 5000:5000
kubectl port-forward -n ecommerce-poc svc/go-inventory 8080:8080
```

### Grafana Datasources

| Name | Type | URL |
|------|------|-----|
| Prometheus | prometheus | http://prometheus:9090 |
| Loki | loki | http://loki:3100 |
| Tempo | tempo | http://tempo:3200 |

## Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| EKS Control Plane | ~$73 |
| EC2 Nodes (2x t3.medium) | ~$60 |
| NAT Gateway | ~$32 |
| EBS Volumes (60GB gp3) | ~$6 |
| **Total** | **~$171/month** |

## Verification Commands

```bash
# Check nodes
kubectl get nodes

# Check all pods
kubectl get pods -A

# Check PVCs
kubectl get pvc -n monitoring

# Check storage class
kubectl get sc

# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs
```

## Cleanup Commands

```bash
# Delete K8s resources
kubectl delete -k k8s/

# Destroy infrastructure
cd terraform && terraform destroy -auto-approve
```
