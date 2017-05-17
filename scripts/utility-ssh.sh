#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../terraform/_env/azure"

utility=$(terraform output utility)
private_key=$(terraform output private_key)

exec ssh \
  -o UserKnownHostsFile=/dev/null \
  -o StrictHostKeyChecking=no \
  -i "${private_key}" \
  ubuntu@${utility}
