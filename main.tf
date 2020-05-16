# Configure the Microsoft Azure Provider.
provider "azurerm" {
  version = "~>1.31"
}

# Create a resource group
resource "azurerm_resource_group" "jenkins" {
  name     = "jenkins-resources"
  location = "westus"
}

# Create virtual network
resource "azurerm_virtual_network" "jenkins" {
  name                = "acctvn"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
}

# Create subnet
resource "azurerm_subnet" "jenkins" {
  name                 = "acctsub"
  resource_group_name  = azurerm_resource_group.jenkins.name
  virtual_network_name = azurerm_virtual_network.jenkins.name
  address_prefix       = "10.0.2.0/24"
}

# Create public IP Address
resource "azurerm_public_ip" "jenkins" {
  name                = "publicip"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  allocation_method   = "Static"
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "jenkins" {
  name                = "nsg"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create virtual network interface
resource "azurerm_network_interface" "jenkins" {
  name                = "acctni"
  location            = azurerm_resource_group.jenkins.location
  resource_group_name = azurerm_resource_group.jenkins.name
  network_security_group_id = azurerm_network_security_group.jenkins.id

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.jenkins.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins.id
  }
}

# Create a Linux virtual machine

resource "azurerm_virtual_machine" "jenkins" {
  name                  = "acctvm"
  location              = azurerm_resource_group.jenkins.location
  resource_group_name   = azurerm_resource_group.jenkins.name
  network_interface_ids = [azurerm_network_interface.jenkins.id]
  vm_size               = "Standard_B1s"

  storage_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.7"
    version   = "latest"
  }

  storage_os_disk {
    name          = "myosdisk1"
    caching       = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "master-jenkins"
    admin_username = "azurebitra"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_virtual_machine_extension" "jenkins" {
  name                 = "master-jenkins"
  virtual_machine_id   = azurerm_virtual_machine.jenkins.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "wget -O azurejenkins.sh https://git.io/AzureJenkins && sh azurejenkins.sh"
    }
SETTINGS


  tags = {
    environment = "Production"
  }
}

output "ip" {
  value = azurerm_public_ip.jenkins.ip_address
}
