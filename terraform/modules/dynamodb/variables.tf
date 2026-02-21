variable "table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "hash_key" {
  description = "Hash key attribute name"
  type        = string
  default     = "id"
}

variable "replica_regions" {
  description = "List of regions for global table replicas"
  type        = list(string)
}

variable "stream_enabled" {
  description = "Enable DynamoDB streams"
  type        = bool
  default     = true
}

variable "stream_view_type" {
  description = "Stream view type"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}

variable "point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
