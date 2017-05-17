output "user_data" { value = "${file("${path.module}/consul_server.sh.tpl")}" }
