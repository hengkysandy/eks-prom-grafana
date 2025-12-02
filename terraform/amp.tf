# Amazon Managed Prometheus Workspace
resource "aws_prometheus_workspace" "main" {
  alias = "ecommerce-poc-amp"

  tags = {
    Name        = "ecommerce-poc-amp"
    Environment = "poc"
    ManagedBy   = "terraform"
  }
}

# IAM Role for Prometheus Remote Write (IRSA)
resource "aws_iam_role" "amp_ingest" {
  name = "ecommerce-poc-amp-ingest-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:monitoring:amp-iamproxy-ingest"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "ecommerce-poc-amp-ingest-role"
  }
}

resource "aws_iam_role_policy_attachment" "amp_ingest" {
  role       = aws_iam_role.amp_ingest.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
}

# IAM Role for Grafana to Query AMP (IRSA)
resource "aws_iam_role" "amp_query" {
  name = "ecommerce-poc-amp-query-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:monitoring:grafana"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "ecommerce-poc-amp-query-role"
  }
}

resource "aws_iam_role_policy_attachment" "amp_query" {
  role       = aws_iam_role.amp_query.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess"
}
