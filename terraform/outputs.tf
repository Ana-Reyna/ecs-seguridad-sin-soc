output "region" {
  value = var.region
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.this.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
