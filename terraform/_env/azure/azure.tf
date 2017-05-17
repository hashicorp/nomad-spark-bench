variable disk_image {
  description = "URL of the disk image built with Packer. See README.md for instructions."
}

variable arm_client_secret {
  description = "Client secret used to access the API on VMs to build the Consul cluster. See README.md for explanation."
}

variable "public_key_path" {
  description = <<END
    Path to an SSH public key to use in the cluster,
    which is uploaded to the cluster for the nodes to access each other.
    The default path is built as shown in README.md.
  END
  default = "../../../cluster_ssh_key.pub"
}

variable "private_key_path" {
  description = <<END
    Path to an SSH private key to use in the cluster,
    which is uploaded to the cluster for the nodes to access each other.
    The default path is built as shown in README.md.
  END
  default = "../../../cluster_ssh_key.pem"
}

variable "name"     { default = "spark-load-test" }

variable "location" { default = "eastus2" }

variable "net_cidr"    { default = "10.0.0.0/8" }
variable "subnet_cidr" { default = "10.139.0.0/16" }

variable "utility_machine"       { default = "Standard_F8" }
variable "utility_disk"          { default = "50" }

variable "consul_server_machine" { default = "Standard_F8" }
variable "consul_server_disk"    { default = "10" }
variable "consul_servers"        { default = "3" }

variable "nomad_server_machine"  { default = "Standard_F8" }
variable "nomad_server_disk"     { default = "500" }
variable "nomad_servers"         { default = "3" }

variable "hdfs_namenode_machine" { default = "Standard_F8" }
variable "hdfs_namenode_disk"    { default = "10" }

variable "yarn_resourcemanager_machine" { default = "Standard_F8" }
variable "yarn_resourcemanager_disk"    { default = "10" }

variable "worker_machine"        { default = "Standard_F8" }
variable "worker_disk"           { default = "20" }
variable "worker_groups"         { default = "4" }
variable "workers"               { default = "100" }

variable "consul_log_level" { default = "INFO" }
variable "nomad_log_level"  { default = "INFO" }


data "azurerm_client_config" "current" { }

resource "azurerm_resource_group" "cluster" {
  name     = "${var.name}"
  location = "${var.location}"
}

module "cluster" {
  source = "../../azure/cluster"

  name              = "${var.name}"

  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.cluster.name}"

  net_cidr    = "${var.net_cidr}"
  subnet_cidr = "${var.subnet_cidr}"

  disk_image = "${var.disk_image}"

  utility_machine       = "${var.utility_machine}"
  utility_disk          = "${var.utility_disk}"

  consul_server_machine = "${var.consul_server_machine}"
  consul_server_disk    = "${var.consul_server_disk}"
  consul_servers        = "${var.consul_servers}"

  nomad_server_machine  = "${var.nomad_server_machine}"
  nomad_server_disk     = "${var.nomad_server_disk}"
  nomad_servers         = "${var.nomad_servers}"

  hdfs_namenode_machine = "${var.hdfs_namenode_machine}"
  hdfs_namenode_disk    = "${var.hdfs_namenode_disk}"

  yarn_resourcemanager_machine = "${var.yarn_resourcemanager_machine}"
  yarn_resourcemanager_disk    = "${var.yarn_resourcemanager_disk}"

  worker_machine        = "${var.worker_machine}"
  worker_disk           = "${var.worker_disk}"
  worker_groups         = "${var.worker_groups}"
  workers               = "${var.workers}"

  public_key  = "${file(var.public_key_path)}"
  private_key = "${file(var.private_key_path)}"

  vm_client_id     = "${data.azurerm_client_config.current.client_id}"
  vm_client_secret = "${var.arm_client_secret}"
  vm_tenant_id     = "${data.azurerm_client_config.current.tenant_id}"

  consul_log_level = "${var.consul_log_level}"
  nomad_log_level  = "${var.nomad_log_level}"
}

output "private_key"  { value = "${var.private_key_path}" }
output "subnet"       { value = "${var.subnet_cidr}" }
output "cluster_info" { value = "${module.cluster.info}" }
output "utility"      { value = "${module.cluster.utility_ip}" }
