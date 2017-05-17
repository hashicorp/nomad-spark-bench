output "user_data" { value = "${file("${path.module}/yarn_resourcemanager.sh.tpl")}" }
