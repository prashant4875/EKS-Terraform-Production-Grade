output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "node_group_arn" {
  description = "ARN of the EKS node group"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.main.status
}

output "node_role_arn" {
  description = "IAM role ARN for the node group"
  value       = aws_iam_role.node_group.arn
}

output "security_group_id" {
  description = "Security group ID for the node group"
  value       = aws_security_group.node_group.id
}