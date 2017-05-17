#!/bin/bash
set -e

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT spark.sh: $1"
}

logger "Executing"

logger "Fetching Spark"
SPARKDIST=spark-2.1.0-bin-nomad
SPARKDOWNLOAD=https://spark-nomad-europe.s3.amazonaws.com/$SPARKDIST.tgz
SPARKDIR=/usr/local
cd /tmp
curl -L $SPARKDOWNLOAD > spark.tgz

logger "Installing Spark"
sudo tar -C $SPARKDIR -xzf spark.tgz

SPARK_HOME=$SPARKDIR/spark
sudo mv $SPARKDIR/$SPARKDIST $SPARK_HOME
echo "SPARK_HOME=$SPARK_HOME" | sudo tee -a /etc/environment

logger "Completed"
