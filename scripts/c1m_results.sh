#!/bin/bash
set -e

NOMAD_HOST=$1
echo "Nomad Server Host: $NOMAD_HOST"
UTILITY_HOST=$2
echo "Utility Host: $UTILITY_HOST"
NODES=$3
NAME=$4
echo "Name: $NAME"
RESULTS=results/${NODES}_nodes/${NAME}
echo "Results Folder: $RESULTS"
DT=$(date '+%s')

mkdir -p "$RESULTS"

echo "Downloading C1M results"
ssh -o StrictHostKeyChecking=no ubuntu@${NOMAD_HOST} 'sudo mv /opt/nomad/jobs/result.csv /home/ubuntu/c1m/results/$(date '+%s').csv'
scp -C -o StrictHostKeyChecking=no ubuntu@${NOMAD_HOST}:/home/ubuntu/c1m/results/*.csv ${RESULTS}/.
ssh -o StrictHostKeyChecking=no ubuntu@${NOMAD_HOST} 'cd /home/ubuntu/c1m/results && sudo rename.ul .csv .csv.exported *.csv'
# ssh -o StrictHostKeyChecking=no ubuntu@${NOMAD_HOST} 'sudo rm -rf /home/ubuntu/c1m/results/*.exported'

echo "Downloading C1M statsite logs"
ssh -o StrictHostKeyChecking=no ubuntu@${UTILITY_HOST} 'sudo mv /opt/statsite/data/sink.log /home/ubuntu/c1m/logs/$(date '+%s').log'
scp -C -o StrictHostKeyChecking=no ubuntu@${UTILITY_HOST}:/home/ubuntu/c1m/logs/*.log ${RESULTS}/.
ssh -o StrictHostKeyChecking=no ubuntu@${UTILITY_HOST} 'cd /home/ubuntu/c1m/logs && sudo rename.ul .log .log.exported *.log'
# ssh -o StrictHostKeyChecking=no ubuntu@${UTILITY_HOST} 'sudo rm -rf /home/ubuntu/c1m/logs/*.exported'

exit 0
