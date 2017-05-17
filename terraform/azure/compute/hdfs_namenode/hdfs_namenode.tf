variable "name"                { default = "hdfs-namenode" }
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
variable "consul_log_level"    { }
variable "public_key"          { }
variable "private_key"         { }
variable "os_user_name"        { default = "ubuntu" }
variable "data_dir"            { }

module "hdfs_namenode_template" {
  source = "../../../templates/hdfs_namenode"
}

data "template_file" "user_data" {
  template = "${module.hdfs_namenode_template.user_data}"

  vars {
    cloud_specific    = "${var.azure_init}"
    private_key       = "${var.private_key}"
    data_dir          = "${var.data_dir}"
    provider          = "azure"
    region            = "azure-${var.location}"
    datacenter        = "azure-${var.location}"
    zone              = "(no zone)"
    machine_type      = "${var.machine_type}"
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
  name                         = "${var.name}-pub-ip"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_network_interface" "vm_pub_nic" {
  name                = "${var.name}-pub-ip-nic"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  tags {
    LoadTestAgent = "${var.resource_group_name}"
  }

  ip_configuration {
    name                          = "${var.name}-pub-ip-config"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.vm_pub_ip.id}"
  }
}

resource "random_id" "admin_password" {
  byte_length = 32
}

resource "azurerm_virtual_machine" "vm" {
  name                          = "${var.name}"
  location                      = "${var.location}"
  resource_group_name           = "${var.resource_group_name}"
  network_interface_ids         = ["${azurerm_network_interface.vm_pub_nic.id}"]
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
    name          = "${var.name}-osdisk"
    vhd_uri       = "${var.sa_blob_endpoint}${var.container_name}/${var.name}-osdisk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
    image_uri     = "${var.image}"
    os_type       = "linux"
  }
  os_profile {
    computer_name  = "${var.name}"
    admin_username = "${var.os_user_name}"
    admin_password = "${random_id.admin_password.b64}"
    custom_data = "${data.template_file.user_data.rendered}"
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
    Name    = "${var.name}"
    Type    = "${var.name}"
    Machine = "${var.machine_type}"
  }
}

output "name"       { value = "${azurerm_virtual_machine.vm.name}" }
output "private_ip" { value = "${azurerm_network_interface.vm_pub_nic.private_ip_address}" }
output "public_ip"  { value = "${azurerm_public_ip.vm_pub_ip.ip_address}" }
