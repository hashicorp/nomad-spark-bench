#!/usr/bin/env bash
set -euo pipefail

scripts_dir=$(dirname "$0")

set -x

#consul exec -service nomad-client "cat > /load-test-nomad-template.json" <load-test-nomad-template.json

rm -rf /home/ubuntu/loadtest/results/

${scripts_dir}/run.sh nomad 1 100
${scripts_dir}/run.sh yarn  1 100

${scripts_dir}/run.sh nomad 10 100
${scripts_dir}/run.sh yarn  10 100

${scripts_dir}/run.sh nomad 100 100
${scripts_dir}/run.sh yarn  100 100

${scripts_dir}/run.sh nomad 1000 100
${scripts_dir}/run.sh yarn  1000 100
