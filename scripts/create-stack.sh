#!/bin/bash
# Script to create a new Terraform stack with proper backend configuration

set -e

if [ -z "$1" ]; then
  echo "Usage: ./create-stack.sh <stack-name>"
  echo "Example: ./create-stack.sh app2"
  exit 1
fi

STACK_NAME=$1
STACK_DIR="terraform/stacks/$STACK_NAME"

if [ -d "$STACK_DIR" ]; then
  echo "Error: Stack '$STACK_NAME' already exists at $STACK_DIR"
  exit 1
fi

echo "Creating new stack: $STACK_NAME"

# Copy template
cp -r terraform/stacks/_template "$STACK_DIR"

# Update backend.tf with correct key
sed -i "s/STACK_NAME/$STACK_NAME/g" "$STACK_DIR/backend.tf"

# Update tfvars files
sed -i "s/mystack/$STACK_NAME/g" "$STACK_DIR/dev.tfvars"
sed -i "s/mystack/$STACK_NAME/g" "$STACK_DIR/qa.tfvars"
sed -i "s/mystack/$STACK_NAME/g" "$STACK_DIR/prod.tfvars"

echo "✅ Stack created at: $STACK_DIR"
echo ""
echo "Backend configuration:"
echo "  S3 Key: $STACK_NAME/terraform.tfstate"
echo "  DynamoDB: terraform-state-lock"
echo ""
echo "Next steps:"
echo "  1. Edit $STACK_DIR/main.tf to add your infrastructure"
echo "  2. Review $STACK_DIR/*.tfvars files"
echo "  3. Create workflow: .github/workflows/terraform-$STACK_NAME.yml"
echo ""
echo "To deploy:"
echo "  cd $STACK_DIR"
echo "  terraform init"
echo "  terraform plan -var-file=dev.tfvars"
