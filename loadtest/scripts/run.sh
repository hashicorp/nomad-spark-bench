#!/usr/bin/env bash
set -euo pipefail

fail() {
    echo "$@"
    exit 1
} >&2

[ -n "$SPARK_HOME" ] || fail "error: SPARK_HOME must be specified"
[ -n "$NOMAD_ADDR" ] || fail "error: NOMAD_ADDR must be specified"
#[ -n "$HADOOP_CONF" ] || fail "error: HADOOP_CONF must be specified"

[ $# -ge 3 ] || fail "usage: $0 (nomad|yarn) <apps> <executors-per-app> [args]..."

cluster="$1"
count="$2"
executors="$3"
shift 3

name="${cluster}-${count}-apps-${executors}-executors"
results_dir="$PWD/results/${name}"
! [ -e "${results_dir}" ] || fail "error: results directory ${results_dir} already exists"
mkdir -p "${results_dir}"

# In additional to logging to the stdout and stderr, combine them in a file
output_log="${results_dir}/load-test.log"
exec >  >(tee -ia "${output_log}")
exec 2> >(tee -ia "${output_log}" >&2)

log() {
    echo
    echo "$(date +%s) ${name} $@"
}

log "Triggering Nomad garbage collection"
curl -sS -XPUT nomad-server.service.consul:4646/v1/system/gc

log "Creating clean internal-load-test-events folders on workers"
consul exec -service nomad-client 'sudo rm -rf /mnt/internal-load-test-events && mkdir -p /mnt/internal-load-test-events'

log "Running Nomad job to submit ${count} applications"
logs_dir="${results_dir}/invocation-logs"
mkdir -p "${logs_dir}"

jars=$(printf 'local://%s,' $SPARK_HOME/jars/*)
sed \
  -e "s|{{name}}|${name}|g" \
  -e "s|{{count}}|${count}|g" \
  -e "s|{{jars}}|${jars}|g" \
  -e "s|{{executors}}|${executors}|g" \
  submit-apps-to-${cluster}.nomad \
  > ${results_dir}/submit.nomad
nomad run ${results_dir}/submit.nomad

log "Waiting until ${count} applications have finished"
finished=0
while [ "${finished}" -lt "${count}" ]; do
  sleep 30
  log "Collecting logs from workers..."
  consul exec -service nomad-client "scp -r -C -q -o StrictHostKeyChecking=no -i /home/ubuntu/c1m/site.pem /mnt/internal-load-test-events ubuntu@utility.service.consul:${results_dir}/" || :
  collected="$(ls ${results_dir}/internal-load-test-events/ | wc -l)"
  echo "Logs collected:        ${collected} of ${count}"
  finished="$(cat ${results_dir}/internal-load-test-events/* 2>/dev/null | grep -c ',ApplicationEnd' || :)"
  echo "Applications finished: ${finished} of ${count}"
done

echo
echo "Parsing log files"
cat ${results_dir}/internal-load-test-events/* \
    | java \
        -cp "spark-load-test.jar:$SPARK_HOME/jars/*" \
        com.hashicorp.nomad.spark.RunningTotals \
    | tee "${results_dir}/internal-event-running-totals.csv"
