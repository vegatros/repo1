#!/bin/bash
# Remove old ec2 state directory from S3

echo "Removing old ec2 state files from S3..."

# Remove entire ec2 directory
aws s3 rm s3://terraform-state-925185632967/ec2/ --recursive

echo "Done! Old ec2 state files removed."
echo ""
echo "Current state structure:"
echo "  - app1/terraform.tfstate"
echo "  - app2/terraform.tfstate"
