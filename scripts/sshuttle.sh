#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../terraform/_env/azure"

utility=$(terraform output utility)
private_key=$(terraform output private_key)
subnet=$(terraform output subnet)

#  --ssh-cmd "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${private_key} -L 8500:127.0.0.1:8500 -L 4646:nomad.service.consul:4646" \

exec sshuttle \
  --dns \
  --ssh-cmd "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${private_key}" \
  -v \
  -r "ubuntu@${utility}" \
  "${subnet}"
