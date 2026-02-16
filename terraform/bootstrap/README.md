# Bootstrap Infrastructure

Creates the DynamoDB table for Terraform state locking.

## Usage

Run this once to create the DynamoDB table:

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

This creates:
- DynamoDB table: `terraform-state-lock`
- Billing mode: PAY_PER_REQUEST (no upfront costs)

After creation, all other Terraform configurations can use state locking.
