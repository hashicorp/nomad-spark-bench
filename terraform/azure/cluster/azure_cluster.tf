variable "name"              { }

variable "location"            { }
variable "resource_group_name" { }

variable "net_cidr"    { }
variable "subnet_cidr" { }

variable "disk_image" { }

variable "utility_machine"       { }
variable "utility_disk"          { }

variable "consul_server_machine" { }
variable "consul_server_disk"    { }
variable "consul_servers"        { }

variable "nomad_server_machine"  { }
variable "nomad_server_disk"     { }
variable "nomad_servers"         { }

variable "hdfs_namenode_machine" { }
variable "hdfs_namenode_disk"    { }

variable "yarn_resourcemanager_machine" { }
variable "yarn_resourcemanager_disk"    { }

variable "worker_machine"  { }
variable "worker_disk"     { }
variable "worker_groups"   { }
variable "workers"         { }

variable vm_client_id     { }
variable vm_client_secret { }
variable vm_tenant_id     { }

variable "public_key"  { }
variable "private_key" { }

variable "consul_log_level" { }
variable "nomad_log_level"  { }


module "network" {
  source = "../network"

  name            = "${var.name}"
  location          = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  net_cidr            = "${var.net_cidr}"
  subnet_cidr            = "${var.subnet_cidr}"
}

module "storage" {
  source = "../storage"
}

module "compute" {
  source = "../compute"

  name                = "${var.name}"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  disk_image       = "${var.disk_image}"
  sa_blob_endpoint = "${module.storage.disk_blob_endpoint}"
  container_name   = "${module.storage.disk_container_name}"

  subnet_id         = "${module.network.subnet_id}"

  vm_client_id        = "${var.vm_client_id}"
  vm_client_secret    = "${var.vm_client_secret}"
  vm_tenant_id        = "${var.vm_tenant_id}"

  consul_log_level  = "${var.consul_log_level}"
  nomad_log_level   = "${var.nomad_log_level}"
  public_key        = "${var.public_key}"
  private_key       = "${var.private_key}"

  utility_machine = "${var.utility_machine}"
  utility_disk    = "${var.utility_disk}"

  consul_server_machine = "${var.consul_server_machine}"
  consul_server_disk    = "${var.consul_server_disk}"
  consul_servers        = "${var.consul_servers}"

  nomad_server_machine = "${var.nomad_server_machine}"
  nomad_server_disk    = "${var.nomad_server_disk}"
  nomad_servers        = "${var.nomad_servers}"

  hdfs_namenode_machine = "${var.hdfs_namenode_machine}"
  hdfs_namenode_disk    = "${var.hdfs_namenode_disk}"

  yarn_resourcemanager_machine = "${var.yarn_resourcemanager_machine}"
  yarn_resourcemanager_disk    = "${var.yarn_resourcemanager_disk}"

  worker_machine = "${var.worker_machine}"
  worker_disk    = "${var.worker_disk}"
  worker_groups  = "${var.worker_groups}"
  workers        = "${var.workers}"
}

output "info" {
  value = <<INFO

Utility server:
    ${module.compute.utility_name}: private ${module.compute.utility_private_ip}, public ${module.compute.utility_public_ip}

Consul servers:
    ${join("\n    ", formatlist("%s: private %s, public %s", split(",", module.compute.consul_server_names), split(",", module.compute.consul_server_private_ips), split(",", module.compute.consul_server_public_ips)))}

HDFS NameNode:
  ${module.compute.hdfs_namenode_name}: private ${module.compute.hdfs_namenode_private_ip}, public ${module.compute.hdfs_namenode_public_ip}

YARN ResourceManager:
  ${module.compute.yarn_resourcemanager_name}: private ${module.compute.yarn_resourcemanager_private_ip}, public ${module.compute.yarn_resourcemanager_public_ip}

Workers:
    ${join("\n    ", formatlist("%s: private %s, public %s", split(",", module.compute.nomad_server_names), split(",", module.compute.nomad_server_private_ips), split(",", module.compute.nomad_server_public_ips)))}

consul dns:
    utility.service.consul
    redis.service.consul
    statsite.service.consul
    graphite.service.consul

    consul-server.service.consul
        ${var.location}.consul-server.service.consul
        ${var.consul_server_machine}.consul-server.service.consul

    nomad-server.service.consul
        ${var.location}.nomad-server.service.consul
        ${var.nomad_server_machine}.nomad-server.service.consul

    nomad-client.service.consul
        ${var.location}.nomad-client.service.consul
        ${var.worker_machine}.nomad-client.service.consul
        NODE_CLASS.nomad-client.service.consul
INFO
}

output "utility_ip" {
  value = "${module.compute.utility_public_ip}"
}
