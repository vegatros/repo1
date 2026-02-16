# Stack Template

Template for creating new Terraform stacks with pre-configured state locking.

## Usage

1. **Copy template:**
   ```bash
   cp -r terraform/stacks/_template terraform/stacks/mystack
   ```

2. **Update backend.tf:**
   - Change `STACK_NAME` to your stack name (e.g., `mystack`)

3. **Update tfvars:**
   - Edit `dev.tfvars`, `qa.tfvars`, `prod.tfvars`
   - Change `project_name` values

4. **Add infrastructure:**
   - Edit `main.tf` to use modules from `terraform/modules/`

5. **Create workflow:**
   - Copy `.github/workflows/terraform-app1.yml`
   - Rename to `terraform-mystack.yml`
   - Update paths and names

## Features

- ✅ S3 backend with encryption
- ✅ DynamoDB state locking
- ✅ Multi-environment tfvars (dev, qa, prod)
- ✅ AWS provider configured
- ✅ Standard variables (project_name, environment, aws_region)

## Example

```hcl
# main.tf
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = var.project_name
  vpc_cidr     = "10.0.0.0/16"
  
  tags = {
    Environment = var.environment
  }
}
```
