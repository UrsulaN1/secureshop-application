# US-052: Configure AWS CloudWatch monitoring for EKS/AWS infrastructure.
# Place this file under terraform/ (e.g. terraform/monitoring.tf) and wire in var.eks_cluster_name.
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.project_name}-${var.environment}/cluster"
  retention_in_days = 30
}

resource "aws_cloudwatch_metric_alarm" "eks_node_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EKS node CPU utilization above 80% for 15 minutes"
  dimensions = {
    ClusterName = "${var.project_name}-${var.environment}"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecr_repo_unscanned" {
  alarm_name          = "${var.project_name}-${var.environment}-ecr-scan-findings"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 1
  metric_name         = "RepositoryImageScanFindingsHigh"
  namespace           = "AWS/ECR"
  period              = 3600
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "High-severity vulnerability findings detected in ECR image scan"
}
