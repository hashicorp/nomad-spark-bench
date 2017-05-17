variable "name"                { default = "nomad-server" }
variable "azure_init"          { }
variable "location"            { }
variable "resource_group_name" { }
variable "sa_blob_endpoint"    { }
variable "container_name"      { }
variable "subnet_id"           { }
variable "image"               { }
variable "machine_type"        { }
variable "disk_size"           { default = "10" }
variable "mount_dir"           { default = "/mnt/ssd0" }
variable "local_ssd_name"      { default = "local-ssd-0" }
variable "servers"             { }
variable "nomad_join_name"     { default = "nomad-server?passing" }
variable "nomad_log_level"     { }
variable "consul_log_level"    { }
variable "public_key"          { }
variable "private_key"         { }
variable "os_user_name"        { default = "ubuntu" }
variable "data_dir"            { }

module "nomad_server_template" {
  source = "../../../templates/nomad_server"
}

data "template_file" "user_data" {
  template = "${module.nomad_server_template.user_data}"
  count    = "${var.servers}"

  vars {
    cloud_specific    = "${var.azure_init}"
    private_key       = "${var.private_key}"
    data_dir          = "${var.data_dir}"
    provider          = "azure"
    region            = "azure-${var.location}"
    datacenter        = "azure-${var.location}"
    bootstrap_expect  = "${var.servers}"
    zone              = "(no zone)"
    machine_type      = "${var.machine_type}"
    nomad_join_name   = "${var.nomad_join_name}"
    nomad_log_level   = "${var.nomad_log_level}"
    consul_log_level  = "${var.consul_log_level}"
    local_ip_url      = "-H Metadata:true \"http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipaddress/0/ipaddress?api-version=2017-03-01&format=text\""
  }
}

//module "mount_ssd_template" {
//  source = "../../../templates/mount_ssd"
//
//  mount_dir      = "${var.mount_dir}"
//  local_ssd_name = "aws-${var.local_ssd_name}"
//}

resource "azurerm_public_ip" "vm_pub_ip" {
  count                        = "${var.servers}"
  name                         = "${var.name}-pub-ip-${count.index}"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_network_interface" "vm_pub_nic" {
  count               = "${var.servers}"
  name                = "${var.name}-pub-ip-nic-${count.index}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  tags {
    LoadTestAgent = "${var.resource_group_name}"
  }

  ip_configuration {
    name                          = "${var.name}-pub-ip-config"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.vm_pub_ip.*.id, count.index)}"
  }
}

resource "random_id" "admin_password" {
  count       = "${var.servers}"
  byte_length = 32
}

resource "azurerm_virtual_machine" "vms" {
  count                         = "${var.servers}"
  name                          = "${var.name}-${count.index}"
  location                      = "${var.location}"
  resource_group_name           = "${var.resource_group_name}"
  network_interface_ids         = ["${element(azurerm_network_interface.vm_pub_nic.*.id, count.index)}"]
  vm_size                       = "${var.machine_type}"
  delete_os_disk_on_termination = "true"


  /*
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }
  */

  storage_os_disk {
    name          = "${var.name}-osdisk-${count.index}"
    vhd_uri       = "${var.sa_blob_endpoint}${var.container_name}/${var.name}-osdisk-${count.index}.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
    image_uri     = "${var.image}"
    os_type       = "linux"
  }
  os_profile {
    computer_name  = "${var.name}-${count.index}"
    admin_username = "${var.os_user_name}"
    admin_password = "${element(random_id.admin_password.*.b64, count.index)}"
    custom_data = "${element(data.template_file.user_data.*.rendered, count.index)}"
  }
  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.os_user_name}/.ssh/authorized_keys"
//      key_data = "${file("${path.root}/../../scripts/ssh_keys/demo.pub")}"
      key_data = "${var.public_key}"
    }

  }
  tags {
    Name    = "${var.name}-${count.index + 1}"
    Type    = "${var.name}"
    Machine = "${var.machine_type}"
  }
}

output "names"       { value = "${join(",", azurerm_virtual_machine.vms.*.name)}" }
output "private_ips" { value = "${join(",", azurerm_network_interface.vm_pub_nic.*.private_ip_address)}" }
output "public_ips"  { value = "${join(",", azurerm_public_ip.vm_pub_ip.*.ip_address)}" }
