# App5 — Bedrock Agent

Amazon Bedrock agent deployment using Titan text model.

## Architecture

- **Bedrock Agent**: Amazon Titan Express v1 foundation model
- **IAM Role**: Service role with InvokeModel permissions
- **Agent Alias**: Production alias for versioning

## Deploy

```bash
cd terraform/stacks/app5
terraform init
terraform plan -var-file="vars/dev.tfvars"
terraform apply -var-file="vars/dev.tfvars"
```

## Destroy

```bash
terraform destroy -var-file="vars/dev.tfvars"
```

## Outputs

- `bedrock_agent_role_arn`: IAM role ARN
- `bedrock_agent_id`: Agent ID
- `bedrock_agent_alias_id`: Alias ID
