variable "prefix" {
  description = "Prefix for naming resources"
  default     = "avd"
}

variable "location" {
  description = "Azure region where resources will be deployed"
  default     = "East US"
}

variable "admin_username" {
  description = "Admin username for the virtual machine"
  default     = "adminuser"
}

variable "admin_password" {
  description = "Admin password for the virtual machine"
  type        = string
  sensitive   = true
}

variable "vnet_resource_group_name" {
  description = "Resource Group containing the existing Virtual Network"
}

variable "nsg_resource_group_name" {
  description = "Resource Group containing the existing Network Security Group"
}

variable "avd_resource_group_name" {
  description = "Resource Group for Azure Virtual Desktop deployments"
}

variable "existing_vnet_name" {
  description = "Name of the existing Virtual Network"
}

variable "existing_subnet_name" {
  description = "Name of the existing Subnet"
}

variable "existing_nsg_name" {
  description = "Name of the existing Network Security Group"
}

variable "aad_group_object_id" {
  description = "Object ID of the Azure Active Directory group to assign to the application group"
}

variable "rdsh_count" {
  description = "Number of AVD session hosts to deploy"
  default     = 1
}

variable "vm_size" {
  description = "Size of the virtual machines to deploy"
  default     = "Standard_DS2_v2"
}

variable "domain_name" {
  description = "Name of the domain to join"
}

variable "domain_user_upn" {
  description = "Username for domain join (without domain name)"
}

variable "domain_password" {
  description = "Password for domain join user"
  type        = string
  sensitive   = true
}

variable "ou_path" {
  description = "OU path to join the domain"
  default     = ""
}
