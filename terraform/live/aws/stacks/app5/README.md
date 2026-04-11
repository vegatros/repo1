# App6 — Serverless S3 Static Website

Serverless static website hosted on S3 with CloudFront CDN and custom domain.

## Architecture

```mermaid
graph TB
    Users((Users)) --> R53[Route53]
    R53 --> CF[CloudFront CDN<br/>HTTPS + Custom Domain]
    
    subgraph AWS["AWS Cloud"]
        CF --> OAC[Origin Access<br/>Control]
        OAC --> S3[S3 Bucket<br/>Static Website]
        
        ACM[ACM Certificate<br/>TLS/SSL<br/>us-east-1]
        
        subgraph Content["Website Content"]
            S3 --> HTML[index.html<br/>futurev-landing]
            S3 --> ERR[error.html]
        end
    end
    
    ACM -.->|Certificate| CF
    R53 -.->|DNS Validation| ACM
    
    style Users fill:#4a90e2,color:#fff
    style R53 fill:#8c6bb1,color:#fff
    style CF fill:#ff9900,color:#fff
    style S3 fill:#569a31,color:#fff
    style ACM fill:#dd344c,color:#fff
    style AWS fill:#f0f0f0
    style Content fill:#e8f5e9
```

## Features

- HTTPS by default via CloudFront
- Custom domain: futurev.io + www
- Global CDN distribution
- Custom error pages
- Gzip compression
- Low latency content delivery
- Free SSL/TLS certificate from ACM

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
- `website_url`: https://futurev.io
- `acm_certificate_arn`: SSL certificate ARN

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

## DNS Configuration

The domain uses Route53 hosted zone `Z3LLP0B81D4CRA` with:
- A record: futurev.io → CloudFront
- A record: www.futurev.io → CloudFront
- CNAME: ACM validation record (auto-created)
