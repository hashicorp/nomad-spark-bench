output "user_data" { value = "${file("${path.module}/nomad_server.sh.tpl")}" }
