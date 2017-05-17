#!/bin/bash
set -e

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT load_test.sh: $1"
}

logger "Executing"

GODIR=/usr/local
GOROOT=$GODIR/go
GOPATH=/opt/go
GOSRC=$GOPATH/src

export GOROOT=$GOROOT
export GOPATH=$GOPATH
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

ORG=barnardb
REPO=c1m
CHECKOUT=master
ORGPATH=$GOSRC/github.com/$ORG
REPOPATH=$ORGPATH/$REPO

logger "Pulling $ORG/$REPO repo"
sh /ops/packer/scripts/git_repo.sh $ORG $REPO $CHECKOUT

logger "Installing SBT shim"
curl -Ls https://git.io/sbt | sudo tee /usr/local/bin/sbt >/dev/null
sudo chmod 0755 /usr/local/bin/sbt

logger "Building load test JAR"
cd ${REPOPATH}/loadtest
export SPARK_HOME=/usr/local/spark
./build.sh

logger "Building docker image"
./build-docker-image.sh

logger "Saving docker image"
docker save spark:load-test > /spark-load-test-image.tar

logger "Moving load test jar to /"
mv spark-load-test.jar /

logger "Completed"
