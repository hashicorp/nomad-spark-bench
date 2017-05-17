variable "name"              { }

variable vm_client_id     { }
variable vm_client_secret { }
variable vm_tenant_id     { }

variable "resource_group_name" { }
variable "location"            { }

variable "disk_image" { }

variable "sa_blob_endpoint" { }
variable "container_name"   { }
variable "subnet_id"        { }
variable "consul_log_level" { }
variable "nomad_log_level"  { }
variable "public_key"       { }
variable "private_key"      { }

variable "utility_machine" { }
variable "utility_disk"    { }

variable "consul_server_machine" { }
variable "consul_server_disk"    { }
variable "consul_servers"        { }

variable "nomad_server_machine" { }
variable "nomad_server_disk"    { }
variable "nomad_servers"        { }

variable "hdfs_namenode_machine" { }
variable "hdfs_namenode_disk"    { }

variable "yarn_resourcemanager_machine" { }
variable "yarn_resourcemanager_disk"    { }

variable "worker_machine" { }
variable "worker_disk"    { }
variable "worker_groups"  { }
variable "workers"        { }

variable "data_dir" { default = "/mnt" }

data "template_file" "azure_init" {
  template = <<EOH
    logger "Logging-in to Azure CLI"
    az login -u "${var.vm_client_id}" -p "${var.vm_client_secret}" --service-principal --tenant "${var.vm_tenant_id}"

    logger "Looking-up consul agent IPs"
    CONSUL_AGENT_IPS=$(az network nic list --resource-group "${var.resource_group_name}" --query "[].ipConfigurations[0].privateIpAddress" | jq --compact-output .)

    logger "Configuring consul to join other agents"
    sudo sed -i -- "s/{{ cloud_specific }}/\"retry_join\": $CONSUL_AGENT_IPS,/g" /etc/consul.d/default.json
  EOH
}

module "utility" {
  source = "./utility"

  name                = "${var.name}-utility"
  azure_init          = "${data.template_file.azure_init.rendered}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  sa_blob_endpoint    = "${var.sa_blob_endpoint}"
  container_name      = "${var.container_name}"
  subnet_id           = "${var.subnet_id}"
  image               = "${var.disk_image}"
  machine_type        = "${var.utility_machine}"
  disk_size           = "${var.utility_disk}"
  consul_log_level    = "${var.consul_log_level}"
  public_key          = "${var.public_key}"
  private_key         = "${var.private_key}"
  data_dir            = "${var.data_dir}"
}

module "consul_servers" {
  source = "./consul_server"

  name                = "${var.name}-consul-server"
  azure_init          = "${data.template_file.azure_init.rendered}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  sa_blob_endpoint    = "${var.sa_blob_endpoint}"
  container_name      = "${var.container_name}"
  subnet_id           = "${var.subnet_id}"
  image               = "${var.disk_image}"
  machine_type        = "${var.consul_server_machine}"
  disk_size           = "${var.consul_server_disk}"
  servers             = "${var.consul_servers}"
  consul_log_level    = "${var.consul_log_level}"
  public_key          = "${var.public_key}"
  private_key         = "${var.private_key}"
  data_dir            = "${var.data_dir}"
}

module "nomad_servers" {
  source = "./nomad_server"

  name                = "${var.name}-nomad-server"
  azure_init          = "${data.template_file.azure_init.rendered}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  sa_blob_endpoint    = "${var.sa_blob_endpoint}"
  container_name      = "${var.container_name}"
  subnet_id           = "${var.subnet_id}"
  image               = "${var.disk_image}"
  machine_type        = "${var.nomad_server_machine}"
  disk_size           = "${var.nomad_server_disk}"
  servers             = "${var.nomad_servers}"
  nomad_log_level     = "${var.nomad_log_level}"
  consul_log_level    = "${var.consul_log_level}"
  public_key          = "${var.public_key}"
  private_key         = "${var.private_key}"
  data_dir            = "${var.data_dir}"
}

module "hdfs_namenode" {
  source = "./hdfs_namenode"

  name                = "${var.name}-hdfs-namenode"
  azure_init          = "${data.template_file.azure_init.rendered}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  sa_blob_endpoint    = "${var.sa_blob_endpoint}"
  container_name      = "${var.container_name}"
  subnet_id           = "${var.subnet_id}"
  image               = "${var.disk_image}"
  machine_type        = "${var.hdfs_namenode_machine}"
  disk_size           = "${var.hdfs_namenode_disk}"
  consul_log_level    = "${var.consul_log_level}"
  public_key          = "${var.public_key}"
  private_key         = "${var.private_key}"
  data_dir            = "${var.data_dir}"
}

module "yarn_resourcemanager" {
  source = "./yarn_resourcemanager"

  name                = "${var.name}-yarn-resourcemanager"
  azure_init          = "${data.template_file.azure_init.rendered}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  sa_blob_endpoint    = "${var.sa_blob_endpoint}"
  container_name      = "${var.container_name}"
  subnet_id           = "${var.subnet_id}"
  image               = "${var.disk_image}"
  machine_type        = "${var.yarn_resourcemanager_machine}"
  disk_size           = "${var.yarn_resourcemanager_disk}"
  consul_log_level    = "${var.consul_log_level}"
  public_key          = "${var.public_key}"
  private_key         = "${var.private_key}"
  data_dir            = "${var.data_dir}"
}

module "worker" {
  source = "worker"

  name                = "${var.name}-worker"
  azure_init          = "${data.template_file.azure_init.rendered}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  sa_blob_endpoint    = "${var.sa_blob_endpoint}"
  container_name      = "${var.container_name}"
  subnet_id           = "${var.subnet_id}"
  image               = "${var.disk_image}"
  machine_type        = "${var.worker_machine}"
  disk_size           = "${var.worker_disk}"
  groups              = "${var.worker_groups}"
  clients             = "${var.workers}"
  nomad_log_level     = "${var.nomad_log_level}"
  consul_log_level    = "${var.consul_log_level}"
  public_key          = "${var.public_key}"
  private_key         = "${var.private_key}"
  data_dir            = "${var.data_dir}"
}

output "utility_name"       { value = "${module.utility.name}" }
output "utility_private_ip" { value = "${module.utility.private_ip}" }
output "utility_public_ip"  { value = "${module.utility.public_ip}" }

output "consul_server_names"       { value = "${module.consul_servers.names}" }
output "consul_server_private_ips" { value = "${module.consul_servers.private_ips}" }
output "consul_server_public_ips"  { value = "${module.consul_servers.public_ips}" }

output "nomad_server_names"       { value = "${module.nomad_servers.names}" }
output "nomad_server_private_ips" { value = "${module.nomad_servers.private_ips}" }
output "nomad_server_public_ips"  { value = "${module.nomad_servers.public_ips}" }

output "hdfs_namenode_name"       { value = "${module.hdfs_namenode.name}" }
output "hdfs_namenode_private_ip" { value = "${module.hdfs_namenode.private_ip}" }
output "hdfs_namenode_public_ip"  { value = "${module.hdfs_namenode.public_ip}" }

output "yarn_resourcemanager_name"       { value = "${module.yarn_resourcemanager.name}" }
output "yarn_resourcemanager_private_ip" { value = "${module.yarn_resourcemanager.private_ip}" }
output "yarn_resourcemanager_public_ip"  { value = "${module.yarn_resourcemanager.public_ip}" }
