module "bedrock" {
  source = "../../../modules/bedrock"

  aws_region         = var.aws_region
  agent_name         = var.agent_name
  agent_instruction  = var.agent_instruction
}
