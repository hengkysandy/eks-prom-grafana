output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}

output "node_group_name" {
  description = "EKS Node Group name"
  value       = aws_eks_node_group.main.node_group_name
}

output "node_role_arn" {
  description = "IAM Role ARN for EC2 nodes"
  value       = aws_iam_role.eks_node_role.arn
}

output "ecr_nodejs_repository_url" {
  description = "ECR repository URL for Node.js service"
  value       = aws_ecr_repository.nodejs_service.repository_url
}

output "ecr_python_repository_url" {
  description = "ECR repository URL for Python service"
  value       = aws_ecr_repository.python_service.repository_url
}

output "ecr_go_repository_url" {
  description = "ECR repository URL for Go service"
  value       = aws_ecr_repository.go_service.repository_url
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "oidc_provider_arn" {
  description = "OIDC Provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}
