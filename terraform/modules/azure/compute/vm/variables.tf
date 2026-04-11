variable "name" {
  description = "VM name (used as prefix for all resources)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the NIC"
  type        = string
}

variable "vm_size" {
  description = "VM SKU size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for admin user"
  type        = string
}

variable "image" {
  description = "Source image reference"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "os_disk_type" {
  description = "OS disk storage account type"
  type        = string
  default     = "StandardSSD_LRS"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

variable "data_disk_size_gb" {
  description = "Data disk size in GB (0 = no data disk)"
  type        = number
  default     = 0
}

variable "data_disk_type" {
  description = "Data disk storage account type"
  type        = string
  default     = "StandardSSD_LRS"
}

variable "create_public_ip" {
  description = "Attach a public IP to the VM"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
