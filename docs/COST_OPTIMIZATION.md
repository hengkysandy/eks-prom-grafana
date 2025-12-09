# Cost Optimization Guide

## Current Cost Breakdown

| Resource | Monthly Cost | Notes |
|----------|-------------|-------|
| EKS Control Plane | ~$73 | Fixed cost |
| EC2 Nodes (2x t3.medium) | ~$60 | $0.0416/hr each |
| NAT Gateway | ~$32 | $0.045/hr + data |
| EBS Volumes (60GB gp3) | ~$6 | $0.08/GB |
| Data Transfer | ~$5 | Variable |
| **Total** | **~$176/month** | |

## Cost Saving Strategies

### 1. Use Spot Instances (Save 60-90%)

```hcl
# terraform/main.tf
resource "aws_eks_node_group" "main" {
  capacity_type = "SPOT"  # Instead of ON_DEMAND
  
  instance_types = ["t3.medium", "t3a.medium"]  # Multiple types for availability
}
```

**Savings**: ~$36/month → ~$12/month for nodes

### 2. Right-Size Instances

Check actual usage:
```bash
kubectl top nodes
```

If using <50% resources, consider:
- t3.small (2 vCPU, 2GB) - $0.0208/hr
- t3.micro (2 vCPU, 1GB) - $0.0104/hr

### 3. Reduce NAT Gateway Costs

Option A: NAT Instance (cheaper but less reliable)
```hcl
# Use t3.nano NAT instance: ~$3/month vs $32/month
```

Option B: Schedule NAT Gateway (dev environments)
- Delete during non-business hours
- Recreate when needed

### 4. Optimize Storage

Current allocation vs usage:
| Volume | Allocated | Used | Recommendation |
|--------|-----------|------|----------------|
| Prometheus | 30GB | ~50MB | Reduce to 10GB |
| Grafana | 10GB | ~2MB | Reduce to 5GB |
| Loki | 10GB | ~15MB | Reduce to 5GB |
| Tempo | 10GB | ~20MB | Reduce to 5GB |

**Potential savings**: ~$2/month

### 5. Use Reserved Instances (Save 30-60%)

For production workloads running 24/7:
- 1-year reserved: ~30% savings
- 3-year reserved: ~60% savings

### 6. Implement Auto-Scaling Down

Scale to 0 during off-hours (dev/test):
```bash
# Scale down at night
kubectl scale deployment --all -n ecommerce-poc --replicas=0

# Scale up in morning
kubectl scale deployment nodejs-catalog -n ecommerce-poc --replicas=1
kubectl scale deployment python-orders -n ecommerce-poc --replicas=1
kubectl scale deployment go-inventory -n ecommerce-poc --replicas=1
```

## Development vs Production Costs

### Development Environment
| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| EKS | Same | $73 |
| Nodes | 1x t3.small Spot | ~$3 |
| NAT | t3.nano instance | ~$3 |
| EBS | 20GB total | ~$2 |
| **Total** | | **~$81/month** |

### Production Environment
| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| EKS | Same | $73 |
| Nodes | 3x t3.medium Reserved | ~$65 |
| NAT | 2x NAT Gateway (HA) | ~$64 |
| EBS | 100GB gp3 | ~$8 |
| ALB | Application Load Balancer | ~$20 |
| **Total** | | **~$230/month** |

## Monitoring Costs

### AWS Cost Explorer

```bash
# Enable Cost Explorer in AWS Console
# Set up budget alerts
aws budgets create-budget \
  --account-id <account-id> \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

### Kubecost (Optional)

Deploy Kubecost for Kubernetes cost visibility:
```bash
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace
```

## Quick Wins Checklist

- [ ] Delete unused EBS volumes
- [ ] Remove unattached Elastic IPs
- [ ] Clean up old ECR images
- [ ] Review and delete unused security groups
- [ ] Check for idle load balancers
- [ ] Review CloudWatch log retention
- [ ] Delete old snapshots
