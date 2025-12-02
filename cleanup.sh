#!/bin/bash

# ⚠️ WARNING: This script will destroy ALL resources created by this PoC
# 
# SAFETY: This script is DISABLED by default.
# To enable, change SAFETY_ENABLED to "false" below.

SAFETY_ENABLED="true"

if [ "$SAFETY_ENABLED" = "true" ]; then
  echo "=========================================="
  echo "⚠️  SAFETY MODE ENABLED"
  echo "=========================================="
  echo ""
  echo "This script will destroy all AWS resources."
  echo "To enable, edit this file and set SAFETY_ENABLED=\"false\""
  echo ""
  echo "Manual cleanup steps:"
  echo ""
  echo "1. Delete Kubernetes resources:"
  echo "   cd k8s"
  echo "   kubectl delete -k ."
  echo ""
  echo "2. Wait for pods to terminate (2-3 minutes)"
  echo "   kubectl get pods -n ecommerce-poc"
  echo "   kubectl get pods -n monitoring"
  echo ""
  echo "3. Destroy Terraform resources:"
  echo "   cd terraform"
  echo "   terraform destroy"
  echo ""
  echo "4. Verify cleanup:"
  echo "   aws eks list-clusters --region ap-southeast-1"
  echo "   aws ecr describe-repositories --region ap-southeast-1"
  echo "   aws grafana list-workspaces --region ap-southeast-1"
  echo "   aws ec2 describe-nat-gateways --region ap-southeast-1"
  echo ""
  exit 0
fi

# If safety is disabled, proceed with cleanup
echo "=========================================="
echo "⚠️  DESTROYING ALL RESOURCES"
echo "=========================================="
echo ""
echo "This will delete:"
echo "  - All Kubernetes resources"
echo "  - EKS cluster"
echo "  - ECR repositories and images"
echo "  - Amazon Managed Grafana workspace"
echo "  - NAT Gateway and Elastic IP"
echo "  - Private subnets"
echo "  - CloudWatch log groups"
echo ""
read -p "Type 'DELETE' to confirm: " confirmation

if [ "$confirmation" != "DELETE" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
echo "Step 1: Deleting Kubernetes resources..."
cd k8s
kubectl delete -k . || echo "Warning: Some K8s resources may not exist"

echo ""
echo "Waiting 3 minutes for pods to terminate..."
sleep 180

echo ""
echo "Step 2: Destroying Terraform resources..."
cd ../terraform
terraform destroy -auto-approve

echo ""
echo "Step 3: Verifying cleanup..."
echo ""
echo "Remaining EKS clusters:"
aws eks list-clusters --region ap-southeast-1

echo ""
echo "Remaining ECR repositories:"
aws ecr describe-repositories --region ap-southeast-1 --query 'repositories[?starts_with(repositoryName, `ecommerce-`)].repositoryName'

echo ""
echo "Remaining Grafana workspaces:"
aws grafana list-workspaces --region ap-southeast-1 --query 'workspaces[?name==`ecommerce-poc-grafana`].id'

echo ""
echo "Remaining NAT Gateways:"
aws ec2 describe-nat-gateways --region ap-southeast-1 --filter "Name=state,Values=available" --query 'NatGateways[?contains(Tags[?Key==`Name`].Value, `ecommerce-poc`)].NatGatewayId'

echo ""
echo "=========================================="
echo "✅ Cleanup complete!"
echo "=========================================="
echo ""
echo "Please verify in AWS Console that all resources are deleted."
