# E-Commerce Microservices PoC on AWS EKS Fargate

Complete proof-of-concept for deploying a 3-microservice e-commerce application to AWS EKS using Fargate Spot, with full observability stack.

## 🚀 Quick Links

- **[Getting Started from Scratch](GETTING_STARTED.md)** - Complete step-by-step guide with explanations
- **[Deployment Summary](DEPLOYMENT_SUMMARY.md)** - Current state and what's deployed
- **[Quick Reference](QUICK_REFERENCE.md)** - Common commands and queries
- **[Changes Log](CHANGES.md)** - Recent updates and modifications

## 📖 Documentation Guide

**New to this project?** Start here:
1. Read [GETTING_STARTED.md](GETTING_STARTED.md) - Explains everything from zero
2. Follow the 7 phases to deploy (~38 minutes)
3. Use [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for daily operations

**Already deployed?** Quick access:
- [DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md) - What's currently running
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Common commands
- [k8s/README.md](k8s/README.md) - Kubernetes details

## Architecture

- **Region**: ap-southeast-1
- **Compute**: EKS with Fargate Spot (no EC2 nodes)
- **Services**: 3 microservices (Node.js, Python, Go)
- **Monitoring**: In-cluster Prometheus + Grafana + kube-state-metrics
- **Logging**: Fargate logging → CloudWatch Logs
- **Registry**: Amazon ECR
- **Dashboards**: Custom HTTP metrics + 3 imported Kubernetes dashboards

## How It Works - Data Flow

### Application Metrics Flow
```
1. Microservices expose /metrics endpoint (Prometheus format)
   ├── Node.js (port 3000) → prom-client library
   ├── Python (port 5000) → prometheus-client library
   └── Go (port 8080) → prometheus/client_golang library

2. Prometheus scrapes metrics every 15 seconds
   ├── Discovers pods via Kubernetes API
   ├── Filters by label (app=nodejs-catalog, etc.)
   └── Stores time-series data in memory

3. Grafana queries Prometheus
   ├── Pre-configured datasource (http://prometheus.monitoring.svc.cluster.local:9090)
   ├── Dashboards use PromQL queries
   └── Displays real-time metrics
```

### Kubernetes Metrics Flow
```
1. kube-state-metrics watches Kubernetes API
   ├── Monitors pods, deployments, nodes, services
   └── Exposes metrics on port 8080

2. Prometheus scrapes kube-state-metrics
   ├── Job: kube-state-metrics
   └── Stores K8s object state metrics

3. Grafana dashboards query both sources
   ├── Application metrics (http_requests_total)
   └── Kubernetes metrics (kube_pod_info, kube_deployment_status_replicas)
```

### Logging Flow
```
1. Application writes logs to stdout/stderr
2. Fargate captures container logs
3. aws-observability ConfigMap routes to CloudWatch
4. Logs appear in: /aws/eks/ecommerce-poc-eks/application
```

## Project Structure

```
.
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # EKS, ECR, networking
│   ├── variables.tf       # Configuration variables
│   ├── outputs.tf         # Output values
│   └── README_TERRAFORM.md
├── k8s/                   # Kubernetes manifests
│   ├── namespace.yaml
│   ├── *-deployment.yaml  # Service deployments
│   ├── traffic-generator.yaml
│   ├── prometheus/        # Prometheus + kube-state-metrics
│   ├── grafana/           # Grafana + dashboard scripts
│   ├── fargate-logging.yaml
│   ├── load-test.sh       # Load testing script
│   └── kustomization.yaml
├── apps/                  # Application code
│   ├── nodejs/            # Catalog service
│   ├── python/            # Orders service
│   ├── go/                # Inventory service
│   └── build-and-push.sh  # Build script
├── CHECKLIST_BEFORE_APPLY.md
├── IAM_permissions.md
└── README.md (this file)
```

## Prerequisites

- AWS CLI v2.x configured
- Docker Desktop running
- kubectl installed
- Terraform >= 1.0
- AWS Account: `683031685817`
- Region: `ap-southeast-1`

## Step-by-Step Deployment

### Step 0: Pre-Flight Check

**⚠️ READ THIS FIRST: `CHECKLIST_BEFORE_APPLY.md`**

Verify your setup:
```bash
aws sts get-caller-identity
aws configure get region
docker ps
kubectl version --client
terraform version
```

### Step 1: Create Infrastructure (Terraform)

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# 🛑 HALT - Review the plan output carefully
# Verify: VPC ID, region, account ID, resource count

# Apply (creates EKS, ECR, Grafana, networking)
terraform apply
# Type: yes

# Expected duration: 10-15 minutes
```

**Capture outputs:**
```bash
terraform output > ../terraform-outputs.txt
```

### Step 2: Build and Push Docker Images

```bash
cd ../apps

# Authenticate with ECR
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin \
  683031685817.dkr.ecr.ap-southeast-1.amazonaws.com

# Build and push all images
./build-and-push.sh

# Expected duration: 3-5 minutes
```

**Verify images:**
```bash
aws ecr describe-images --repository-name ecommerce-nodejs-catalog --region ap-southeast-1
aws ecr describe-images --repository-name ecommerce-python-orders --region ap-southeast-1
aws ecr describe-images --repository-name ecommerce-go-inventory --region ap-southeast-1
```

### Step 3: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-southeast-1 --name ecommerce-poc-eks

# Verify connection
kubectl get nodes
kubectl get pods -n kube-system
```

**Note:** Fargate nodes won't show in `kubectl get nodes`. Check pods instead.

### Step 4: Deploy Kubernetes Resources

```bash
cd ../k8s

# Deploy everything
kubectl apply -k .

# Watch pods starting
kubectl get pods -n ecommerce-poc -w
kubectl get pods -n monitoring -w
```

**Expected pods:**
- `ecommerce-poc` namespace: 4 pods (nodejs, python, go, traffic-generator)
- `monitoring` namespace: 3 pods (prometheus, grafana, kube-state-metrics)

**Troubleshooting:**
```bash
# If pods are pending
kubectl describe pod <pod-name> -n ecommerce-poc

# Check Fargate profiles
aws eks list-fargate-profiles --cluster-name ecommerce-poc-eks --region ap-southeast-1
```

### Step 5: Verify Services

**Port-forward to test each service:**

```bash
# Node.js Catalog (Terminal 1)
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000

# Python Orders (Terminal 2)
kubectl port-forward -n ecommerce-poc svc/python-orders 5000:5000

# Go Inventory (Terminal 3)
kubectl port-forward -n ecommerce-poc svc/go-inventory 8080:8080

# Prometheus (Terminal 4)
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

**Test endpoints:**
```bash
# Health checks
curl http://localhost:3000/health
curl http://localhost:5000/health
curl http://localhost:8080/health

# Business endpoints
curl http://localhost:3000/products
curl http://localhost:5000/orders
curl http://localhost:8080/inventory

# Metrics
curl http://localhost:3000/metrics
curl http://localhost:9090/targets  # Prometheus targets
```

### Step 6: Access Grafana

**Port-forward Grafana:**
```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

**Access Grafana:**
- Open: http://localhost:3001
- Username: `admin`
- Password: `admin`

**Prometheus is already configured as the default data source!**

**Import Kubernetes dashboards automatically:**
```bash
cd k8s/grafana
./import-dashboards.sh
```

This imports:
- Dashboard 3119: Kubernetes Cluster Monitoring via Prometheus
- Dashboard 8588: Kubernetes Deployment Statefulset Daemonset metrics
- Dashboard 15760: Kubernetes Views Pods

**Or import manually:**
- Click **+** → **Import**
- Enter dashboard ID (3119, 8588, or 15760)
- Click **Load** → Select **Prometheus** → **Import**

**Query metrics in Explore:**
- `up` - All targets
- `http_requests_total` - Request counts
- `rate(http_requests_total[5m])` - Request rate
- `kube_pod_info` - Pod information
- `kube_deployment_status_replicas` - Deployment status

### Step 7: View Logs in CloudWatch

```bash
# Get log group name
terraform output cloudwatch_log_group_name

# View logs in AWS Console
# Navigate to: CloudWatch → Log Groups → /aws/eks/ecommerce-poc-eks/application
```

Or via CLI:
```bash
aws logs tail /aws/eks/ecommerce-poc-eks/application --follow --region ap-southeast-1
```

### Step 8: Run Load Tests

**Quick load test (30 seconds):**
```bash
cd k8s
./load-test.sh 30
```

**Custom duration:**
```bash
./load-test.sh 60  # 60 seconds
```

This generates traffic to all 3 services and you can observe the metrics in Grafana dashboards.

## Scaling

**Manual scaling (no autoscaling configured):**

```bash
# Scale to 3 replicas
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=3
kubectl scale deployment python-orders -n ecommerce-poc --replicas=3
kubectl scale deployment go-inventory -n ecommerce-poc --replicas=3

# Verify
kubectl get pods -n ecommerce-poc

# Scale back to 1
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=1
kubectl scale deployment python-orders -n ecommerce-poc --replicas=1
kubectl scale deployment go-inventory -n ecommerce-poc --replicas=1
```

## Cost Monitoring

**Estimated monthly costs:**
- EKS Control Plane: ~$73
- Fargate (7 pods): ~$50-60
- NAT Gateway: ~$32
- **Total: ~$155-165/month**

**Set up billing alerts:**
```bash
aws budgets create-budget \
  --account-id 683031685817 \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

## Cleanup (Teardown)

**⚠️ IMPORTANT: Follow this order to avoid orphaned resources**

### 1. Delete Kubernetes resources
```bash
cd k8s
kubectl delete -k .

# Wait for pods to terminate (2-3 minutes)
kubectl get pods -n ecommerce-poc
kubectl get pods -n monitoring
```

### 2. Destroy Terraform resources
```bash
cd ../terraform
terraform destroy
# Type: yes

# Expected duration: 10-15 minutes
```

### 3. Verify cleanup
```bash
# Check EKS clusters
aws eks list-clusters --region ap-southeast-1

# Check ECR repositories
aws ecr describe-repositories --region ap-southeast-1

# Check Grafana workspaces
aws grafana list-workspaces --region ap-southeast-1

# Check NAT Gateways
aws ec2 describe-nat-gateways --region ap-southeast-1 --filter "Name=state,Values=available"

# Check Elastic IPs
aws ec2 describe-addresses --region ap-southeast-1
```

### 4. Manual cleanup (if needed)
```bash
# Delete ECR images
aws ecr batch-delete-image \
  --repository-name ecommerce-nodejs-catalog \
  --image-ids imageTag=latest \
  --region ap-southeast-1

# Release Elastic IP (if not deleted)
aws ec2 release-address --allocation-id <eipalloc-id> --region ap-southeast-1
```

## Troubleshooting

### Pods stuck in Pending
- Check Fargate profiles: `aws eks describe-fargate-profile --cluster-name ecommerce-poc-eks --fargate-profile-name ecommerce-app-profile --region ap-southeast-1`
- Verify namespace matches profile selector
- Check subnet IP availability

### ImagePullBackOff errors
- Verify images exist in ECR
- Check ECR authentication
- Verify image tags match deployment manifests

### Prometheus not scraping
- Check ServiceMonitor configuration
- Verify pod labels match scrape config
- Port-forward to Prometheus and check `/targets`

### Grafana can't connect to Prometheus
- Use kubectl port-forward for PoC
- For production, set up AWS PrivateLink or VPN
- Alternative: Deploy Prometheus with LoadBalancer (costs extra)

## What This PoC Does NOT Include

- TLS/HTTPS (no ingress controller)
- Automatic scaling (HPA/VPA)
- Persistent storage (uses in-memory data)
- CI/CD pipelines
- Multi-environment setup
- Secrets management (uses basic K8s secrets)
- Network policies
- Pod security policies
- Backup/disaster recovery

## Security Notes

- All services use ClusterIP (internal only)
- Access via kubectl port-forward
- No public endpoints exposed
- ECR images scanned on push
- Fargate provides pod-level isolation
- Review `IAM_permissions.md` for least privilege

## Next Steps for Production

1. Implement CI/CD (AWS CodePipeline, GitHub Actions)
2. Add Application Load Balancer + TLS
3. Configure HPA/VPA for autoscaling
4. Set up RDS for persistent data
5. Implement AWS Secrets Manager
6. Add network policies
7. Configure remote Terraform state (S3 + DynamoDB)
8. Set up multi-environment (dev/staging/prod)
9. Implement backup strategy
10. Add comprehensive monitoring/alerting

## Support

For issues with this PoC:
1. Check `terraform/README_TERRAFORM.md`
2. Check `k8s/README.md`
3. Check `apps/README.md`
4. Review AWS CloudWatch logs
5. Check Terraform state: `terraform show`

## License

This is a proof-of-concept for demonstration purposes.
