provider "azurerm" {
  features {}
}

data "azurerm_virtual_network" "existing_vnet" {
  name                = var.existing_vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_subnet" "existing_subnet" {
  name                 = var.existing_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  resource_group_name  = var.vnet_resource_group_name
}

data "azurerm_network_security_group" "existing_nsg" {
  name                = var.existing_nsg_name
  resource_group_name = var.nsg_resource_group_name
}

resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = "${var.prefix}-workspace"
  location            = data.azurerm_virtual_network.existing_vnet.location
  resource_group_name = var.avd_resource_group_name
  friendly_name       = "My AVD Workspace"
  description         = "Azure Virtual Desktop Workspace"
}

resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  name                      = "${var.prefix}-hostpool"
  resource_group_name       = var.avd_resource_group_name
  location                  = data.azurerm_virtual_network.existing_vnet.location
  type                      = "Pooled"
  preferred_app_group_type  = "Desktop"
  maximum_sessions_allowed  = 10
  friendly_name             = "My AVD Host Pool"
  load_balancer_type        = "BreadthFirst"
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "registrationinfo" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = timeadd(timestamp(), "168h") # 7 days
}

locals {
  registration_token = azurerm_virtual_desktop_host_pool_registration_info.registrationinfo.token
}

resource "azurerm_network_interface" "avd_vm_nic" {
  count               = var.rdsh_count
  name                = "${var.prefix}-${count.index + 1}-nic"
  resource_group_name = var.avd_resource_group_name
  location            = data.azurerm_virtual_network.existing_vnet.location

  ip_configuration {
    name                          = "nic${count.index + 1}_config"
    subnet_id                     = data.azurerm_subnet.existing_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "avd_vm" {
  count                 = var.rdsh_count
  name                  = "${var.prefix}-${count.index + 1}"
  resource_group_name   = var.avd_resource_group_name
  location              = data.azurerm_virtual_network.existing_vnet.location
  size                  = var.vm_size
  network_interface_ids = [element(azurerm_network_interface.avd_vm_nic.*.id, count.index)]
  provision_vm_agent    = true
  admin_username        = var.admin_username
  admin_password        = var.admin_password

  os_disk {
    name                 = "${lower(var.prefix)}-${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-23h2-avd"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "domain_join" {
  count                      = var.rdsh_count
  name                       = "${var.prefix}-${count.index + 1}-domainJoin"
  virtual_machine_id         = element(azurerm_windows_virtual_machine.avd_vm.*.id, count.index)
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "Name": "${var.domain_name}",
      "OUPath": "${var.ou_path}",
      "User": "${var.domain_user_upn}@${var.domain_name}",
      "Restart": "true",
      "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "Password": "${var.domain_password}"
    }
PROTECTED_SETTINGS
}

resource "azurerm_virtual_machine_extension" "vmext_dsc" {
  count                      = var.rdsh_count
  name                       = "${var.prefix}${count.index + 1}-avd_dsc"
  virtual_machine_id         = element(azurerm_windows_virtual_machine.avd_vm.*.id, count.index)
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<-SETTINGS
    {
      "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "HostPoolName":"${azurerm_virtual_desktop_host_pool.hostpool.name}"
      }
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "properties": {
        "registrationInfoToken": "${local.registration_token}"
      }
    }
PROTECTED_SETTINGS
}

resource "azurerm_virtual_desktop_application_group" "appgroup" {
  name                = "${var.prefix}-appgroup"
  resource_group_name = var.avd_resource_group_name
  location            = data.azurerm_virtual_network.existing_vnet.location
  host_pool_id        = azurerm_virtual_desktop_host_pool.hostpool.id
  type                = "Desktop"
  friendly_name       = "My AVD App Group"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "association" {
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.appgroup.id
}

resource "azurerm_role_assignment" "appgroup_assignment" {
  principal_id        = var.aad_group_object_id
  role_definition_name = "Desktop Virtualization User"
  scope               = azurerm_virtual_desktop_application_group.appgroup.id
}
