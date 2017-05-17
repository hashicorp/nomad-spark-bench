#!/bin/bash
set -e

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT hadoop.sh: $1"
}

logger "Executing"

logger "Fetching Hadoop"
CONFIGDIR=/ops/$1/hadoop
HADOOPVERSION=2.7.3
HADOOPDOWNLOAD=http://apache.mirror.iphh.net/hadoop/common/hadoop-$HADOOPVERSION/hadoop-$HADOOPVERSION.tar.gz
INSTALL_DIR=/opt
HADOOP_PREFIX=$INSTALL_DIR/hadoop

cd /tmp
curl -L $HADOOPDOWNLOAD > hadoop-$HADOOPVERSION.tar.gz

logger "Installing Hadoop"
sudo tar -C $INSTALL_DIR -xzf hadoop-$HADOOPVERSION.tar.gz
sudo mv $INSTALL_DIR/hadoop-$HADOOPVERSION $HADOOP_PREFIX

logger "Configuring Hadoop"
HADOOP_CONF_DIR=$HADOOP_PREFIX/etc/hadoop
sudo cp $CONFIGDIR/*-site.xml $HADOOP_CONF_DIR/.
echo "HADOOP_PREFIX=$HADOOP_PREFIX" | sudo tee -a /etc/environment
echo "HADOOP_CONF_DIR=$HADOOP_CONF_DIR" | sudo tee -a /etc/environment

# Upstart config
for service in hdfs-namenode hdfs-datanode yarn-resourcemanager yarn-nodemanager; do
  echo manual > /etc/init/${service}.override
  cp $CONFIGDIR/upstart.${service} /etc/init/${service}.conf
done

logger "Completed"
