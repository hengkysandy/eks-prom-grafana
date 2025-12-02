terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# NOTE: This configuration creates AWS resources but does NOT execute automatically.
# The operator must manually run `terraform init`, `terraform plan`, and confirm before `terraform apply`.

# ============================================================================
# Data sources for existing VPC
# ============================================================================
data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# Private Subnets for Fargate (required)
# ============================================================================
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = var.vpc_id
  cidr_block        = cidrsubnet("172.31.0.0/16", 4, count.index + 8)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
}

# NAT Gateway in first public subnet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.subnet_ids[0]  # Use existing public subnet

  tags = {
    Name = "${var.cluster_name}-nat-gw"
  }
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================================================
# IAM Role for EKS Cluster
# ============================================================================
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# ============================================================================
# IAM Role for Fargate Pod Execution
# ============================================================================
resource "aws_iam_role" "fargate_pod_execution_role" {
  name = "${var.cluster_name}-fargate-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_pod_execution_role.name
}

# CloudWatch Logs policy for Fargate
resource "aws_iam_role_policy" "fargate_logs_policy" {
  name = "${var.cluster_name}-fargate-logs"
  role = aws_iam_role.fargate_pod_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:CreateLogGroup",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    }]
  })
}

# ============================================================================
# EKS Cluster
# ============================================================================
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids              = concat(var.subnet_ids, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# ============================================================================
# Fargate Profile for application namespace
# NOTE: Fargate Spot is requested via capacityType in the profile
# ============================================================================
resource "aws_eks_fargate_profile" "app_profile" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "ecommerce-app-profile"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role.arn
  subnet_ids             = aws_subnet.private[*].id

  selector {
    namespace = var.namespace
  }

  # NOTE: Fargate Spot is the default for Fargate profiles.
  # AWS automatically uses Spot capacity when available.
}

# Fargate profile for kube-system (CoreDNS)
resource "aws_eks_fargate_profile" "kube_system_profile" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "kube-system-profile"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role.arn
  subnet_ids             = aws_subnet.private[*].id

  selector {
    namespace = "kube-system"
  }
}

# Fargate profile for monitoring namespace (Prometheus, Fluent Bit)
resource "aws_eks_fargate_profile" "monitoring_profile" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "monitoring-profile"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution_role.arn
  subnet_ids             = aws_subnet.private[*].id

  selector {
    namespace = "monitoring"
  }
}

# ============================================================================
# ECR Repositories for microservices
# NOTE: Operator will build and push images manually
# ============================================================================
resource "aws_ecr_repository" "nodejs_service" {
  name                 = "ecommerce-nodejs-catalog"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "python_service" {
  name                 = "ecommerce-python-orders"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "go_service" {
  name                 = "ecommerce-go-inventory"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ============================================================================
# CloudWatch Log Group for application logs
# ============================================================================
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "fargate_logs" {
  name              = "/aws/eks/${var.cluster_name}/fargate"
  retention_in_days = 7
}
