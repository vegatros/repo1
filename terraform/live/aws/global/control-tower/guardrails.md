# Control Tower Security Guardrails

## Preventive Guardrails (SCPs)

### Root account protection
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": { "StringLike": { "aws:PrincipalArn": "arn:aws:iam::*:root" } }
}
```

### Block leaving the Organization
```json
{ "Effect": "Deny", "Action": "organizations:LeaveOrganization", "Resource": "*" }
```

### Deny disabling CloudTrail / Config
```json
{
  "Effect": "Deny",
  "Action": [
    "cloudtrail:DeleteTrail", "cloudtrail:StopLogging",
    "config:DeleteConfigRule", "config:StopConfigurationRecorder"
  ],
  "Resource": "*"
}
```

### Restrict to approved regions
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {
      "aws:RequestedRegion": ["us-east-1", "us-west-2", "eu-west-1"]
    }
  }
}
```

### Deny public S3 buckets
```json
{
  "Effect": "Deny",
  "Action": ["s3:PutBucketPublicAccessBlock"],
  "Resource": "*",
  "Condition": { "Bool": { "s3:DataAccessPointAccount": "false" } }
}
```

---

## Detective Guardrails (Config Rules)

| Rule | What it detects |
|------|----------------|
| `root-account-mfa-enabled` | Root account has no MFA |
| `iam-user-mfa-enabled` | IAM users without MFA |
| `iam-password-policy` | Weak account password policy |
| `s3-bucket-public-read-prohibited` | Publicly readable S3 buckets |
| `s3-bucket-server-side-encryption-enabled` | Unencrypted S3 buckets |
| `ec2-instance-no-public-ip` | EC2 with public IPs (flag for review) |
| `restricted-ssh` | Security groups allowing `0.0.0.0/0` on port 22 |
| `restricted-common-ports` | SGs open to world on 3389, 3306, 5432 |
| `ebs-encryption-by-default` | EBS encryption not enabled account-wide |
| `vpc-flow-logs-enabled` | VPCs without flow logs |
| `guardduty-enabled-centralized` | GuardDuty not enabled in a region |
| `access-keys-rotated` | IAM access keys older than 90 days |

---

## Guardrails per OU

| OU | Guardrails to apply |
|----|-------------------|
| **Sandbox** | Region restriction, no root usage, CloudTrail protection |
| **Dev/QA** | Above + MFA enforcement, no public S3 |
| **Prod** | All of the above + no public EC2 IPs, encryption at rest, GuardDuty |
| **Security/Log Archive** | Strictest — deny all except security tooling roles |

---

## Implementation

SCPs are implemented via `aws_organizations_policy` resources and Config rules via `aws_config_config_rule`.
See [plan.md](plan.md) for the full Control Tower architecture.
