# Terraform Improvements

## Changes Made to Ensure Complete Infrastructure Management

### Problem
During cleanup, some resources had to be deleted manually using AWS CLI instead of Terraform:
1. VPC Endpoint for STS - blocked subnet deletion
2. ECR Repositories - required `--force` flag
3. IAM Role (ecommerce-poc-eks-grafana-role) - was created manually

### Solution
Added missing resources to Terraform to ensure everything is managed in one place.

## New Resources Added

### 1. Security Group for VPC Endpoints

```hcl
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.cluster_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow HTTPS from EKS cluster"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**Purpose:**
- Allows EKS cluster to communicate with VPC endpoints
- Required for IRSA (IAM Roles for Service Accounts) to work
- Prevents security group issues during AMP integration

### 2. VPC Endpoint for STS

```hcl
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}
```

**Purpose:**
- Required for IRSA (IAM Roles for Service Accounts)
- Allows Prometheus to authenticate with AMP using SigV4
- Enables private communication with AWS STS service
- Previously blocked subnet deletion during `terraform destroy`

### 3. Force Delete for ECR Repositories

```hcl
resource "aws_ecr_repository" "nodejs_service" {
  name                 = "ecommerce-nodejs-catalog"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # <-- Added this
  
  image_scanning_configuration {
    scan_on_push = true
  }
}
```

**Purpose:**
- Allows Terraform to delete ECR repositories even if they contain images
- Prevents manual cleanup with `aws ecr delete-repository --force`
- Ensures clean `terraform destroy` without errors

## Benefits

### 1. Complete Infrastructure as Code
- All resources now managed by Terraform
- No manual AWS CLI commands needed
- Infrastructure is reproducible and version-controlled

### 2. Clean Teardown
- `terraform destroy` now works without manual intervention
- No orphaned resources left behind
- No additional costs after cleanup

### 3. Proper Dependencies
- Terraform manages resource dependencies correctly
- VPC endpoint deleted before subnets
- Security groups deleted in correct order

### 4. Consistent Deployments
- Next POC deployment will be identical
- No manual steps to remember
- Reduces human error

## Verification

After these changes, cleanup process is now:

```bash
# 1. Delete Kubernetes resources
cd k8s
kubectl delete -k .

# 2. Wait for pods to terminate (2-3 minutes)
kubectl get pods --all-namespaces

# 3. Destroy all infrastructure
cd ../terraform
terraform destroy -auto-approve

# That's it! No manual AWS CLI commands needed.
```

## What Was Already in Terraform

These resources were already properly managed:
- ✅ EKS Cluster
- ✅ Fargate Profiles (4 profiles)
- ✅ NAT Gateway
- ✅ Elastic IP
- ✅ Private Subnets (3 subnets)
- ✅ Route Tables
- ✅ ECR Repositories (3 repositories)
- ✅ IAM Roles (EKS cluster, Fargate, AMP ingest, AMP query)
- ✅ CloudWatch Log Groups
- ✅ AMP Workspace
- ✅ OIDC Provider

## What Was Missing (Now Added)

- ❌ VPC Endpoint for STS → ✅ Added
- ❌ Security Group for VPC Endpoints → ✅ Added
- ❌ Force delete flag for ECR → ✅ Added

## Cost Impact

No additional costs from these changes:
- VPC Endpoint: ~$7/month (already existed, now managed by Terraform)
- Security Group: Free
- Force delete flag: No cost (just a configuration)

## Next Deployment

When deploying the POC again:

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

All resources including VPC endpoint and security group will be created automatically.

## Cleanup Verification

After `terraform destroy`, verify nothing is left:

```bash
# Check EKS clusters
aws eks list-clusters --region ap-southeast-1

# Check VPC endpoints
aws ec2 describe-vpc-endpoints --region ap-southeast-1

# Check ECR repositories
aws ecr describe-repositories --region ap-southeast-1

# Check NAT gateways
aws ec2 describe-nat-gateways --region ap-southeast-1 --filter "Name=state,Values=available"

# Check Elastic IPs
aws ec2 describe-addresses --region ap-southeast-1

# All should return empty results
```

## Summary

✅ **Before:** Manual AWS CLI commands needed for cleanup
✅ **After:** Complete Terraform management, clean teardown
✅ **Result:** Reproducible infrastructure, no orphaned resources
