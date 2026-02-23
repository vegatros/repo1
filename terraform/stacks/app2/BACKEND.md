# App2 Backend Configuration

Each environment uses a separate state file to prevent conflicts:

- **dev**: `backend.tf` → `app2/dev/terraform.tfstate`
- **qa**: `backend-qa.tf` → `app2/qa/terraform.tfstate`
- **prod**: `backend-prod.tf` → `app2/prod/terraform.tfstate`

## Usage

When deploying a specific environment, rename the appropriate backend file:

```bash
# For QA deployment
mv backend.tf backend-dev.tf
mv backend-qa.tf backend.tf
terraform init -reconfigure
terraform plan -var-file="vars/qa.tfvars"

# For PROD deployment
mv backend.tf backend-qa.tf
mv backend-prod.tf backend.tf
terraform init -reconfigure
terraform plan -var-file="vars/prod.tfvars"
```

Or use backend config override:

```bash
terraform init -backend-config="key=app2/qa/terraform.tfstate"
terraform plan -var-file="vars/qa.tfvars"
```
