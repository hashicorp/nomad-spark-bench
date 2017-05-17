variable name     { default = "spark-load-test-images" }
variable location { default = "eastus2" }


resource "azurerm_resource_group" "images" {
  name     = "${var.name}"
  location = "${var.location}"
}

resource "azurerm_storage_account" "images" {
  name                = "${replace(lower(var.name), "/[^a-z0-9]/", "")}"
  resource_group_name = "${azurerm_resource_group.images.name}"
  location            = "${var.location}"
  account_type        = "Standard_LRS"
}


output "resource_group" {
  value = "${azurerm_resource_group.images.name}"
}

output "storage_account" {
  value = "${azurerm_storage_account.images.name}"
}

output "blob_endpoint" {
  value = "${azurerm_storage_account.images.primary_blob_endpoint}"
}
