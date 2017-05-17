data "terraform_remote_state" "images" {
  backend = "local"
  config {
    path = "../../_env/azure_images/terraform.tfstate"
  }
}

resource "azurerm_storage_container" "container" {
  name                  = "vm-disks"
  resource_group_name   = "${data.terraform_remote_state.images.resource_group}"
  storage_account_name  = "${data.terraform_remote_state.images.storage_account}"
  container_access_type = "private"
}

output "disk_container_name" {
  value = "${azurerm_storage_container.container.name}"
}

output "disk_blob_endpoint" {
  value = "${data.terraform_remote_state.images.blob_endpoint}"
}
