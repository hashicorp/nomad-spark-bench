#!/bin/bash
set -e

UTILITY_HOST=$1
echo "Utility Host: $UTILITY_HOST"
NODES=$2
RESULTS=results/${NODES}_nodes
echo "Folder: $RESULTS"

mkdir -p "$RESULTS/spawn"
rsync -avz --exclude 'spawn.csv' ubuntu@$UTILITY_HOST:/home/ubuntu/c1m/spawn/*.csv $RESULTS/spawn/.

exit 0
