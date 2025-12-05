output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "cluster_iam_role_arn" {
  description = "EKS cluster IAM role ARN"
  value       = module.eks.cluster_iam_role_arn
}

output "node_iam_role_arn" {
  description = "EKS managed node group IAM role ARN"
  value       = module.eks.eks_managed_node_groups["general-instances"].iam_role_arn
}

output "spire_server_service_account_role_arn" {
  description = "SPIRE server service account IAM role ARN"
  value       = aws_iam_role.spire_server_role.arn
}
