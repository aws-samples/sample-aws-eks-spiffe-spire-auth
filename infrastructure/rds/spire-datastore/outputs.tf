output "aurora_mysql_v2_cluster_endpoint" {
  description = "Writer endpoint for the cluster"
  value       = module.aurora_mysql_v2.cluster_endpoint
}

output "aurora_mysql_v2_cluster_reader_endpoint" {
  description = "A read-only endpoint for the cluster, automatically load-balanced across replicas"
  value       = module.aurora_mysql_v2.cluster_reader_endpoint
}

output "aurora_mysql_v2_cluster_master_user_secret_arn" {
  description = "The Amazon Resource Name (ARN) of the master user secret"
  value       = module.aurora_mysql_v2.cluster_master_user_secret[0].secret_arn
}