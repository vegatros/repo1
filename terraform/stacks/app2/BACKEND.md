# App2 Backend Configuration

The backend state key should match the environment being deployed.

## Current Configuration

`backend.tf` is set to **dev** environment by default:
```
key = "app2/dev/terraform.tfstate"
```

## Deploying Other Environments

Update the `key` in `backend.tf` before deploying:

**For QA:**
```hcl
key = "app2/qa/terraform.tfstate"
```

**For PROD:**
```hcl
key = "app2/prod/terraform.tfstate"
```

Then run:
```bash
terraform init -reconfigure
terraform plan -var-file="vars/{environment}.tfvars"
```

## Alternative: Backend Config Override

Keep `backend.tf` unchanged and override at runtime:

```bash
terraform init -backend-config="key=app2/qa/terraform.tfstate"
terraform plan -var-file="vars/qa.tfvars"
```
