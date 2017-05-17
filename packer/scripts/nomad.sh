#!/bin/bash
set -e

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT nomad.sh: $1"
}

logger "Executing"

cd /tmp

CONFIGDIR=/ops/$1
NOMADVERSION=0.5.6
NOMADDOWNLOAD=https://releases.hashicorp.com/nomad/${NOMADVERSION}/nomad_${NOMADVERSION}_linux_amd64.zip
NOMADCONFIGDIR=/etc/nomad.d
NOMADDIR=/opt/nomad

logger "Fetching Nomad"
curl -L $NOMADDOWNLOAD > nomad.zip

logger "Installing Nomad"
unzip nomad.zip -d /usr/local/bin
chmod 0755 /usr/local/bin/nomad
chown root:root /usr/local/bin/nomad

logger "Configuring Nomad"
mkdir -p "$NOMADCONFIGDIR"
chmod 0755 $NOMADCONFIGDIR
mkdir -p "$NOMADDIR"
chmod 0777 $NOMADDIR
mkdir "$NOMADDIR/data"

# Nomad config
cp $CONFIGDIR/nomad/*.hcl $NOMADCONFIGDIR/.

# Consul config
cp ${CONFIGDIR}/consul/nomad_client.json /etc/consul-optional.d/.
cp ${CONFIGDIR}/consul/nomad_server.json /etc/consul-optional.d/.

# Upstart config
echo manual > /etc/init/nomad.override
cp $CONFIGDIR/nomad/upstart.nomad /etc/init/nomad.conf

# Nomad join script
cp $CONFIGDIR/nomad/nomad_join.sh $NOMADDIR/.
chmod +x $NOMADDIR/nomad_join.sh

logger "Completed"
