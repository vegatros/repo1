output "vpc_id" {
  value = module.vpc.vpc_id
}

output "pipeline_arn" {
  value = aws_sagemaker_pipeline.main.arn
}

output "s3_bucket" {
  value = aws_s3_bucket.pipeline.id
}

output "sagemaker_role_arn" {
  value = aws_iam_role.sagemaker.arn
}
