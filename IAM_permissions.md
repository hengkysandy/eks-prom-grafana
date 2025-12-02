# IAM Permissions Required

## Overview

This document lists the minimum IAM permissions required for different roles in this PoC.

## 1. Terraform Operator (Infrastructure Creation)

The user/role running Terraform needs these permissions:

### EKS Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:CreateCluster",
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:UpdateClusterConfig",
        "eks:UpdateClusterVersion",
        "eks:DeleteCluster",
        "eks:CreateFargateProfile",
        "eks:DescribeFargateProfile",
        "eks:ListFargateProfiles",
        "eks:DeleteFargateProfile",
        "eks:TagResource",
        "eks:UntagResource"
      ],
      "Resource": "*"
    }
  ]
}
```

### IAM Permissions (for creating service roles)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:ListRoles",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": [
        "arn:aws:iam::683031685817:role/ecommerce-poc-eks-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::683031685817:role/ecommerce-poc-eks-*"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": [
            "eks.amazonaws.com",
            "eks-fargate-pods.amazonaws.com",
            "grafana.amazonaws.com"
          ]
        }
      }
    }
  ]
}
```

### VPC/Networking Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:DescribeSubnets",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:DescribeAddresses",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:DescribeNatGateways",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:DescribeRouteTables",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:DescribeVpcs",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeSecurityGroups",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress"
      ],
      "Resource": "*"
    }
  ]
}
```

### ECR Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:DescribeRepositories",
        "ecr:ListTagsForResource",
        "ecr:TagResource",
        "ecr:UntagResource",
        "ecr:PutImageScanningConfiguration",
        "ecr:PutImageTagMutability"
      ],
      "Resource": "arn:aws:ecr:ap-southeast-1:683031685817:repository/ecommerce-*"
    }
  ]
}
```

### CloudWatch Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy",
        "logs:TagLogGroup",
        "logs:UntagLogGroup"
      ],
      "Resource": "arn:aws:logs:ap-southeast-1:683031685817:log-group:/aws/eks/ecommerce-poc-eks/*"
    }
  ]
}
```

### Amazon Managed Grafana Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "grafana:CreateWorkspace",
        "grafana:DeleteWorkspace",
        "grafana:DescribeWorkspace",
        "grafana:ListWorkspaces",
        "grafana:UpdateWorkspace",
        "grafana:TagResource",
        "grafana:UntagResource"
      ],
      "Resource": "*"
    }
  ]
}
```

## 2. Developer (ECR Push Only)

For developers who only need to push Docker images:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:ListImages"
      ],
      "Resource": [
        "arn:aws:ecr:ap-southeast-1:683031685817:repository/ecommerce-nodejs-catalog",
        "arn:aws:ecr:ap-southeast-1:683031685817:repository/ecommerce-python-orders",
        "arn:aws:ecr:ap-southeast-1:683031685817:repository/ecommerce-go-inventory"
      ]
    }
  ]
}
```

## 3. Kubernetes Operator (kubectl Access)

For users who need to deploy and manage Kubernetes resources:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "arn:aws:eks:ap-southeast-1:683031685817:cluster/ecommerce-poc-eks"
    }
  ]
}
```

**Note:** Kubernetes RBAC is managed separately within the cluster.

## Current User Permissions

Your current role: `AWSReservedSSO_AdministratorAccess_32c34ef993c4cc10`

This role has **AdministratorAccess** which includes all required permissions.

## Least Privilege Recommendations

For production environments:
1. Create separate IAM roles for each function
2. Use IAM conditions to restrict actions
3. Enable CloudTrail for audit logging
4. Use AWS Organizations SCPs for guardrails
5. Implement time-based access with temporary credentials

## Verification

Check your current permissions:
```bash
# Verify you can assume the role
aws sts get-caller-identity

# Test EKS permissions
aws eks list-clusters --region ap-southeast-1

# Test ECR permissions
aws ecr describe-repositories --region ap-southeast-1

# Test IAM permissions
aws iam list-roles --max-items 1
```
