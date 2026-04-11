output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.website.id
}

output "bucket_website_endpoint" {
  description = "S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.website.id
}

output "website_url" {
  description = "Website URL"
  value       = "https://${var.domain_name}"
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.website.arn
}

output "route53_nameservers" {
  description = "Route53 nameservers"
  value       = "ns-923.awsdns-51.net, ns-1304.awsdns-35.org, ns-497.awsdns-62.com, ns-1661.awsdns-15.co.uk"
}
