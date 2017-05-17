output "user_data" { value = "${file("${path.module}/worker.sh.tpl")}" }
