output "user_data" { value = "${file("${path.module}/hdfs_namenode.sh.tpl")}" }
