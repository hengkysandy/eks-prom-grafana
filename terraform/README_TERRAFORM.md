# Terraform Configuration for EKS PoC

## ⚠️ SAFETY NOTICE

**This Terraform configuration will create AWS resources that incur costs.**

Before running any commands, review:
1. `CHECKLIST_BEFORE_APPLY.md` in the root directory
2. All `.tf` files in this directory
3. Your AWS billing alerts and budgets

## Resources Created

- **EKS Cluster** (Fargate Spot) - ~$0.10/hour per pod
- **3 ECR Repositories** - $0.10/GB/month storage
- **Amazon Managed Grafana Workspace** - ~$9/month + usage
- **CloudWatch Log Groups** - $0.50/GB ingested
- **IAM Roles** (no cost)

## Prerequisites

```bash
# Verify AWS CLI is configured
aws sts get-caller-identity

# Verify region is set
aws configure get region

# Should return: ap-southeast-1
```

## Step-by-Step Instructions

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

**Review the output carefully.** Verify:
- Correct VPC ID: `vpc-04440292fc58c6a74`
- Correct region: `ap-southeast-1`
- Correct account: `683031685817`
- Expected resource count: ~15 resources

### 3. 🛑 HALT - CONFIRM BEFORE APPLYING

**DO NOT PROCEED without explicit confirmation.**

Resources that will be created:
- EKS cluster with Fargate profiles
- ECR repositories
- Amazon Managed Grafana workspace
- CloudWatch log groups
- IAM roles and policies

**Type the following to confirm:**
```
I confirm I want to create these AWS resources and understand the costs.
```

### 4. Apply Terraform Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**Expected duration:** 10-15 minutes (EKS cluster creation is slow)

### 5. Capture Outputs

```bash
terraform output
```

Save the ECR repository URLs - you'll need them to push Docker images.

## Verification

```bash
# Verify EKS cluster exists
aws eks describe-cluster --name ecommerce-poc-eks --region ap-southeast-1

# Verify ECR repositories
aws ecr describe-repositories --region ap-southeast-1

# Verify Grafana workspace
aws grafana list-workspaces --region ap-southeast-1
```

## Troubleshooting

### Error: VPC not found
- Verify VPC ID in `variables.tf` matches your account
- Check region is correct

### Error: Insufficient permissions
- Review `IAM_permissions.md` in root directory
- Ensure your IAM role has required permissions

### Error: Fargate profile creation failed
- Check subnet IDs are correct and in the specified VPC
- Ensure subnets have available IP addresses

## Cleanup (Teardown)

**⚠️ WARNING: This will destroy all resources**

```bash
# First, delete all Kubernetes resources
kubectl delete namespace ecommerce-poc
kubectl delete namespace monitoring

# Wait 2-3 minutes for pods to terminate

# Then destroy Terraform resources
terraform destroy
```

Type `yes` when prompted.

**Verify cleanup:**
```bash
aws eks list-clusters --region ap-southeast-1
aws ecr describe-repositories --region ap-southeast-1
aws grafana list-workspaces --region ap-southeast-1
```

## State Management

This configuration uses **local state** (`terraform.tfstate`).

**Important:**
- Do NOT commit `terraform.tfstate` to git
- Back up state file if needed
- For production, use remote state (S3 + DynamoDB)
