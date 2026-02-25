# Terraform Code Review

## Architecture Overview

6 application stacks backed by 8 reusable modules. Well-organized `modules/` + `stacks/` layout with per-environment tfvars. S3 backend with DynamoDB locking across all stacks.

---

## Findings

### HIGH Severity

**1. Duplicate/conflicting S3 bucket policies in app6** (`stacks/app6/main.tf:27-44, 146-170`)
Two `aws_s3_bucket_policy` resources target the same bucket (`website` and `cloudfront`). Terraform will apply the last one, silently dropping the public-read policy. Since CloudFront uses OAC, the public-read policy (lines 27-44) is unnecessary and contradicts the OAC pattern. The bucket should be private with only the CloudFront policy.

**2. S3 bucket is publicly accessible despite using CloudFront OAC** (`stacks/app6/main.tf:6-13`)
`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets` are all `false`. When using OAC, the bucket should be private — set all four to `true` and remove the public `aws_s3_bucket_policy.website` resource.

**3. Hardcoded AWS account IDs and IAM user IDs** (`modules/iam/roles/roles.tf:163, 181, 193, 211`)
- Account `002667640586` hardcoded in `AWSControlTowerExecution` and `OrganizationAccountAccessRole`
- IAM user ID `AIDA5O2K4NLD6BL4I7TRO` hardcoded in `eks`, `geodesic`, and `Gitlab_Eks` roles
- These should be variables or use `data.aws_caller_identity`

**4. Hardcoded Route53 zone ID** (`stacks/app3/main.tf:137`)
`zone_id = "Z3LLP0B81D4CRA"` is hardcoded. Other stacks correctly use a variable. This should use `var.route53_zone_id` for consistency.

**5. Overly broad IAM policies** (`stacks/app1/scheduler.tf:26-29`)
EC2 scheduler Lambda has `ec2:StartInstances`, `ec2:StopInstances`, `ec2:DescribeInstances` on `Resource = "*"`. Should be scoped to specific instance ARNs or at minimum tag-based conditions.

**6. DynamoDB policy too broad** (`modules/ec2/main.tf:83`)
`Resource = "arn:aws:dynamodb:*:*:table/*"` grants access to all DynamoDB tables across all regions/accounts. Should be scoped to specific tables.

---

### MEDIUM Severity

**7. ECS module creates its own VPC inline** (`modules/ecs/main.tf:18-65`)
The ECS module hardcodes `cidr_block = "10.0.0.0/16"` and creates VPC/subnets/IGW internally, unlike other modules that accept VPC as input. This makes the module inflexible and inconsistent. The app4 stack works around this by not using the ECS module at all — it builds ECS resources inline while using the VPC module. The ECS module is effectively unused dead code.

**8. Bedrock module embeds provider config** (`modules/bedrock/main.tf:1-12`)
Modules should not contain `provider` blocks or `terraform` blocks with `required_providers`. This prevents multi-region or multi-account usage. The provider should be inherited from the calling stack.

**9. CloudFront viewer_certificate references unvalidated cert** (`stacks/app6/main.tf:131`)
Uses `aws_acm_certificate.website.arn` instead of `aws_acm_certificate_validation.website.certificate_arn`. While the `depends_on` on the distribution catches this, using the validation resource's ARN is the correct pattern (as done in app1).

**10. No HTTPS on app4 ALB** (`stacks/app4/main.tf:152-162`)
ALB listener is HTTP-only (port 80). No HTTPS listener, no ACM certificate, no HTTP-to-HTTPS redirect. Traffic between clients and the ALB is unencrypted.

**11. App3 Global Accelerator health checks port 443, but EC2 likely serves port 80** (`stacks/app3/main.tf:113, 131`)
Health check uses `health_check_port = 443` and `health_check_protocol = "TCP"`, but the EC2 security group only allows port 80. The health checks will fail unless instances are configured for 443.

**12. App1 scheduler only handles first instance** (`stacks/app1/scheduler.tf:71, 88`)
`INSTANCE_ID = module.ec2.instance_ids[0]` — only starts/stops the first instance. In prod with 3 instances, 2 remain unmanaged by the scheduler.

---

### LOW Severity

**13. Flow logs disabled across all stacks**
`enable_flow_logs = false` in app1 and app4. No flow logs configuration in app2/app3. The VPC module supports it but it's never enabled.

**14. ECR `image_tag_mutability = "MUTABLE"` and `force_delete = true`** (`stacks/app4/main.tf:20-21`)
Mutable tags allow image overwrites (supply chain risk). `force_delete` destroys images on `terraform destroy` without confirmation.

**15. Naming inconsistency: "aks" vs "eks"** (`modules/iam/roles/roles.tf:8-13`)
Role named `aks-node-group-1` and `aks-test-2-cluster` — these appear to be Azure AKS naming carried into AWS EKS resources.

**16. `forwarded_values` deprecated in CloudFront** (`stacks/app6/main.tf:112-117`)
Should use `cache_policy_id` with a managed cache policy instead.

**17. CloudWatch log retention inconsistencies**
ECS logs retain for 7 days, VPC flow logs use a variable (default likely 30). No standardized retention policy.

**18. Missing `lifecycle` blocks on stateful resources**
DynamoDB global table and S3 buckets lack `prevent_destroy = true`, making accidental deletion possible.

---

### Structural Observations

- **Good**: Consistent backend config, module reuse for VPC/EC2/EKS, environment isolation via tfvars, IMDSv2 enforced, EBS encryption, default SG restricted
- **Good**: TLS 1.3 on ALB, IRSA support in EKS, KMS encryption for flow logs, scan-on-push for ECR
- **Consider**: The IAM roles file (`roles.tf`) looks like it was exported from an existing account. It would benefit from being broken into separate files or using a `for_each` pattern with a roles map

---

## Summary

| Severity | Count |
|----------|-------|
| High     | 6     |
| Medium   | 6     |
| Low      | 6     |

The most impactful fixes would be: (1) fix the app6 S3 public access + duplicate bucket policy, (2) parameterize hardcoded account IDs and zone IDs, and (3) scope down overly broad IAM policies.
