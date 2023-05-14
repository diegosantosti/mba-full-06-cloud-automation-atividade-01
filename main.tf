terraform {
  required_version = ">=1.4.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.55.0"
    }    
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true # comando utilizado na minha máquina local para skipar alguns providers, acredito que seja por conta da permissão da minha conta  
}

resource "azurerm_resource_group" "rg" {
    name = var.resource_group_name_prefix
    location = var.resource_group_location
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "public-ip" {
  name                = "public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "WEB_HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                = "nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nic-configuration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public-ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nisga" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "vm-001" {
  name                  = "vm-001"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = "Standard_DS1_v2"
  computer_name                   = "vm-001"
  admin_username                  = "adminuser"
  admin_password             = "Teste@1234!"
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

}

resource "null_resource" "install-nginx" {
  triggers = {
    order = azurerm_linux_virtual_machine.vm-001.id
  }

  connection {
    type = "ssh"
    host = azurerm_public_ip.public-ip.ip_address
    user = "adminuser"
    password = "Teste@1234!"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx"
    ]
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm-001
  ]
}

output "vm_001_public_ip_address" {
  value = azurerm_linux_virtual_machine.vm-001.public_ip_address
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}