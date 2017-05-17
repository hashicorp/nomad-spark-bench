#!/bin/bash
set -e

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT dependencies.sh: $1"
}

logger "Executing"

logger "Update the box"
apt-get -y update
apt-get -y upgrade

logger "Install dependencies"
apt-get -y install curl zip unzip tar git jq openjdk-7-jdk
echo "JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64" | sudo tee -a /etc/environment

logger "Completed"
