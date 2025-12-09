# Getting Started Guide

Complete step-by-step guide to deploy the e-commerce microservices PoC on AWS EKS with EC2 nodes.

## Prerequisites

Before starting, ensure you have:

1. **AWS CLI v2** configured with appropriate credentials
2. **Terraform >= 1.0** installed
3. **kubectl** installed
4. **Docker Desktop** running
5. **AWS Account** with permissions for EKS, EC2, ECR, IAM

## Phase 1: Infrastructure Setup (~15 minutes)

### 1.1 Initialize Terraform

```bash
cd terraform
terraform init
```

### 1.2 Review the Plan

```bash
terraform plan
```

Expected resources:
- 1 EKS Cluster (v1.31)
- 1 EC2 Node Group (2x t3.medium)
- 3 Private Subnets
- 1 NAT Gateway + Elastic IP
- 3 ECR Repositories
- EBS CSI Driver Addon
- IAM Roles (cluster, nodes, EBS CSI)

### 1.3 Apply Infrastructure

```bash
terraform apply -auto-approve
```

Wait ~15 minutes for EKS cluster and node group to be ready.

### 1.4 Configure kubectl

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name ecommerce-poc-eks
```

### 1.5 Verify Nodes

```bash
kubectl get nodes
```

Expected output:
```
NAME                                               STATUS   ROLES    AGE   VERSION
ip-172-31-xxx-xxx.ap-southeast-1.compute.internal  Ready    <none>   5m    v1.31.x
ip-172-31-xxx-xxx.ap-southeast-1.compute.internal  Ready    <none>   5m    v1.31.x
```

## Phase 2: Build and Push Images (~5 minutes)

### 2.1 Login to ECR

```bash
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com
```

### 2.2 Build and Push All Images

```bash
cd apps
./build-and-push.sh
```

Or manually:

```bash
# Node.js
cd apps/nodejs
docker build -t 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-nodejs-catalog:latest .
docker push 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-nodejs-catalog:latest

# Python
cd ../python
docker build -t 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-python-orders:latest .
docker push 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-python-orders:latest

# Go
cd ../go
docker build -t 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-go-inventory:latest .
docker push 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-go-inventory:latest
```

## Phase 3: Deploy Kubernetes Resources (~5 minutes)

### 3.1 Deploy All Resources

```bash
cd k8s
kubectl apply -k .
```

This deploys:
- Namespaces (ecommerce-poc, monitoring)
- StorageClass (ebs-gp3)
- Application deployments (3 microservices)
- Monitoring stack (Prometheus, Grafana, Loki, Tempo)
- Persistent Volume Claims

### 3.2 Verify Deployments

```bash
# Check application pods
kubectl get pods -n ecommerce-poc

# Check monitoring pods
kubectl get pods -n monitoring

# Check PVCs
kubectl get pvc -n monitoring
```

Expected PVCs:
```
NAME              STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
prometheus-data   Bound    pvc-xxx  30Gi       RWO            ebs-gp3
grafana-data      Bound    pvc-xxx  10Gi       RWO            ebs-gp3
loki-data         Bound    pvc-xxx  10Gi       RWO            ebs-gp3
tempo-data        Bound    pvc-xxx  10Gi       RWO            ebs-gp3
```

## Phase 4: Access Services

### 4.1 Access Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

Open http://localhost:3001
- Username: `admin`
- Password: `admin`

### 4.2 Access Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Open http://localhost:9090

### 4.3 Test Application Services

```bash
# Port-forward Node.js service
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000

# Test endpoints
curl http://localhost:3000/products
curl http://localhost:3000/health
```

## Phase 5: Verify Observability

### 5.1 Check Prometheus Targets

In Prometheus UI (http://localhost:9090):
- Go to Status → Targets
- Verify all targets are UP

### 5.2 Check Grafana Datasources

In Grafana UI (http://localhost:3001):
- Go to Connections → Data sources
- Verify Prometheus, Loki, Tempo are configured

### 5.3 Generate Test Traffic

```bash
cd k8s
./load-test.sh 60
```

## Cleanup

### Delete Kubernetes Resources

```bash
cd k8s
kubectl delete -k .
```

### Wait for PVCs to be Deleted

```bash
kubectl get pvc -n monitoring
# Wait until all PVCs are deleted
```

### Destroy Infrastructure

```bash
cd terraform
terraform destroy -auto-approve
```

## Troubleshooting

### Pods Stuck in Pending

Check if nodes are ready:
```bash
kubectl get nodes
kubectl describe node <node-name>
```

### PVC Stuck in Pending

Check EBS CSI driver:
```bash
kubectl get pods -n kube-system | grep ebs
kubectl logs -n kube-system -l app=ebs-csi-controller
```

### Image Pull Errors

Verify ECR login:
```bash
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com
```

### Node Group Not Ready

Check node group status:
```bash
aws eks describe-nodegroup --cluster-name ecommerce-poc-eks --nodegroup-name ecommerce-poc-eks-node-group --region ap-southeast-1
```

## Next Steps

1. Import Grafana dashboards from `k8s/grafana/*.json`
2. Set up alerting rules in Prometheus
3. Configure Ingress for external access
4. Add HPA for auto-scaling
