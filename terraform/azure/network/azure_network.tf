variable "name"            { }
variable "location"          { }
variable "resource_group_name"          { }
variable "net_cidr"            { }
variable "subnet_cidr"            { }

resource "azurerm_network_security_group" "standard" {
  name                = "${var.name}-security-group"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  security_rule {
    name                       = "deny-ingress-by-default"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ingress-within-subnet"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "${var.subnet_cidr}"
    destination_address_prefix = "${var.subnet_cidr}"
  }

  security_rule {
    name                       = "http"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "vn" {
  name                = "${var.name}-vn"
  address_space       = ["${var.net_cidr}"]
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.name}-subnet"
  resource_group_name  = "${var.resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.vn.name}"
  address_prefix       = "${var.subnet_cidr}"
  network_security_group_id = "${azurerm_network_security_group.standard.id}"
}

output "subnet_id" { value = "${azurerm_subnet.subnet.id}" }
