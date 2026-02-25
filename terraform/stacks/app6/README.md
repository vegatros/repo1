# App6 — Serverless S3 Static Website

Serverless static website hosted on S3 with CloudFront CDN.

## Architecture

- **S3 Bucket**: Static website hosting with public read access
- **CloudFront**: CDN distribution with HTTPS
- **Origin Access Control**: Secure access from CloudFront to S3
- **Sample Pages**: index.html and error.html

## Features

- HTTPS by default via CloudFront
- Global CDN distribution
- Custom error pages
- Gzip compression
- Low latency content delivery

## Deploy

```bash
cd terraform/stacks/app6
terraform init
terraform plan -var-file="vars/dev.tfvars"
terraform apply -var-file="vars/dev.tfvars"
```

## Destroy

```bash
terraform destroy -var-file="vars/dev.tfvars"
```

## Outputs

- `bucket_name`: S3 bucket name
- `bucket_website_endpoint`: S3 website endpoint
- `cloudfront_domain_name`: CloudFront domain
- `website_url`: Full HTTPS URL

## Upload Content

```bash
aws s3 cp index.html s3://app6-static-website-dev-925185632967/
aws s3 sync ./website s3://app6-static-website-dev-925185632967/
```

## Invalidate CloudFront Cache

```bash
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```
