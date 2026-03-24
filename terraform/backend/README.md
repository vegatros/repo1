# Backend Infrastructure — DECOMMISSIONED

State locking has been migrated from DynamoDB to S3 native locking (`use_lockfile = true`), available in Terraform >= 1.10.

## Cleanup

To remove the legacy DynamoDB table:

```bash
cd terraform/backend
terraform init
terraform destroy
```

After destroying, this directory can be deleted.
