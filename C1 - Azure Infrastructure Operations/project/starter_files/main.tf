terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}


data "azurerm_resource_group" "rg" {
  name = "Azuredevops"
}

data "azurerm_image" "search" {
  name                = "myPackerImage"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "my-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "public-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "my-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.public_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "public_ip" {
  name                = "my-public-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "my-lb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "my-frontend-ip"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name                = "my-backend-pool"
  loadbalancer_id     = azurerm_lb.lb.id
}

resource "azurerm_network_interface" "nic" {
  count                = var.vm_count
  name                 = "my-nic-${count.index}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my-nic-${count.index}"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_backend_pool_association" {
  count                   = var.vm_count
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = azurerm_network_interface.nic[count.index].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

# resource "azurerm_availability_set" "availability_set" {
#   name                = "my-availability-set"
#   location            = data.azurerm_resource_group.rg.location
#   resource_group_name = data.azurerm_resource_group.rg.name

#   platform_fault_domain_count  = 2
#   platform_update_domain_count = 5
# }

# resource "azurerm_virtual_machine" "vm" {
#   count                = var.vm_count
#   name                 = "my-vm-${count.index}"
#   location             = data.azurerm_resource_group.rg.location
#   resource_group_name  = data.azurerm_resource_group.rg.name
#   # availability_set_id  = azurerm_availability_set.availability_set.id
#   network_interface_ids = [azurerm_network_interface.nic.id]
#   vm_size              = "Standard_B1s"

#   storage_image_reference {
#     id = "${data.azurerm_image.search.id}"
#   }

#   storage_os_disk {
#     name              = "osdisk"
#     caching           = "ReadWrite"
#     create_option     = "FromImage"
#     managed_disk_type = "Standard_LRS"
#   }

#   os_profile {
#     computer_name  = "my-vm-${count.index}"
#     admin_username = "adminuser"
#     admin_password = "Adminpassword@123"
#   }

#   os_profile_linux_config {
#     disable_password_authentication = false
#   }

#   tags = {
#     environment = "dev"
#   }
# }

resource "azurerm_linux_virtual_machine" "example" {
  count                = var.vm_count
  name                 = "my-vm-${count.index}"
  location             = data.azurerm_resource_group.rg.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  size                = "Standard_B1s"

  admin_username      = "adminuser"
  admin_password      = "Adminpassword@123"
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = "${data.azurerm_image.search.id}"
  tags = {
    environment = "dev"
    name        = "my-vm-${count.index}"
  }
}

