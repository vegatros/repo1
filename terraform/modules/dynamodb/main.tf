terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws]
    }
  }
}

# DynamoDB Global Table
resource "aws_dynamodb_table" "this" {
  name             = var.table_name
  billing_mode     = var.billing_mode
  hash_key         = var.hash_key
  stream_enabled   = var.stream_enabled
  stream_view_type = var.stream_enabled ? var.stream_view_type : null

  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  attribute {
    name = var.hash_key
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  dynamic "replica" {
    for_each = var.replica_regions
    content {
      region_name            = replica.value
      point_in_time_recovery = var.point_in_time_recovery
    }
  }

  tags = merge(
    {
      Name = var.table_name
    },
    var.tags
  )
}
