# Pre-Flight Checklist

## ⚠️ REVIEW BEFORE CREATING ANY AWS RESOURCES

### 1. AWS Account Verification
- [ ] Correct AWS account: `683031685817`
- [ ] Correct region: `ap-southeast-1`
- [ ] AWS CLI configured and authenticated
  ```bash
  aws sts get-caller-identity
  aws configure get region
  ```

### 2. VPC and Network Verification
- [ ] VPC exists: `vpc-04440292fc58c6a74`
- [ ] VPC has available IP addresses
- [ ] Subnets verified:
  - `subnet-033dfb4d5f93cfea1` (ap-southeast-1a)
  - `subnet-0a4eba8f84c7b50d2` (ap-southeast-1b)
  - `subnet-0a913be6b8f4e0b9f` (ap-southeast-1c)

### 3. IAM Permissions Check
- [ ] You have permissions to create:
  - EKS clusters
  - IAM roles and policies
  - ECR repositories
  - Amazon Managed Grafana workspaces
  - CloudWatch log groups
  - VPC resources (subnets, NAT Gateway, Elastic IP)

### 4. Cost Awareness
Estimated monthly costs:
- **EKS Control Plane**: ~$73/month
- **Fargate Pods** (3 pods @ 0.25 vCPU, 0.5GB): ~$22/month
- **NAT Gateway**: ~$32/month + data transfer
- **Amazon Managed Grafana**: ~$9/month + usage
- **ECR Storage**: ~$0.10/GB/month
- **CloudWatch Logs**: ~$0.50/GB ingested

**Total estimated: ~$140-160/month**

- [ ] I understand these costs
- [ ] I have billing alerts configured
- [ ] I will destroy resources when done with PoC

### 5. Terraform State
- [ ] Using local state (not production-ready)
- [ ] Will back up `terraform.tfstate` file
- [ ] Understand state file contains sensitive data

### 6. Docker and Local Tools
- [ ] Docker installed and running
- [ ] kubectl installed
- [ ] Sufficient disk space for Docker images (~2GB)

### 7. Cleanup Plan
- [ ] I know how to destroy all resources
- [ ] I will verify all resources are deleted
- [ ] I understand orphaned resources may incur costs

## Confirmation Statement

**I have reviewed all items above and understand:**
- The AWS resources that will be created
- The estimated costs
- How to destroy resources when done
- That this is a PoC and not production-ready

**Type this to confirm:**
```
I confirm I am ready to proceed with resource creation.
```

## Emergency Stop

If you need to stop at any point:
1. Press `Ctrl+C` to cancel Terraform
2. Run `terraform destroy` to remove created resources
3. Verify in AWS Console that resources are deleted
