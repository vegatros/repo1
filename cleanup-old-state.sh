#!/bin/bash
# Remove old ec2 state files from S3

echo "Removing old state files..."

# Remove dev state
aws s3 rm s3://terraform-state-925185632967/stacks/app1/dev/terraform.tfstate

# Remove qa state  
aws s3 rm s3://terraform-state-925185632967/stacks/app1/qa/terraform.tfstate

# Remove prod state
aws s3 rm s3://terraform-state-925185632967/stacks/app1/prod/terraform.tfstate

echo "Done! Old state files removed."
