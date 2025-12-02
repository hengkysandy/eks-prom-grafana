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
  description = "Private subnet IDs created for Fargate"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
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

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group for application logs"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# Amazon Managed Prometheus Outputs
output "amp_workspace_id" {
  description = "Amazon Managed Prometheus Workspace ID"
  value       = aws_prometheus_workspace.main.id
}

output "amp_workspace_endpoint" {
  description = "Amazon Managed Prometheus Workspace Endpoint"
  value       = aws_prometheus_workspace.main.prometheus_endpoint
}

output "amp_remote_write_url" {
  description = "AMP Remote Write URL"
  value       = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
}

output "amp_ingest_role_arn" {
  description = "IAM Role ARN for AMP Ingestion"
  value       = aws_iam_role.amp_ingest.arn
}

output "amp_query_role_arn" {
  description = "IAM Role ARN for AMP Query"
  value       = aws_iam_role.amp_query.arn
}
