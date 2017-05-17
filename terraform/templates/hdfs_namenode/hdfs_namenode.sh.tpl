#!/bin/bash
set -e
set -x

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT hdfs_namenode.sh: $1"
  echo "$DT hdfs_namenode.sh: $1" | sudo tee -a /var/log/user_data.log > /dev/null
}

logger "Begin script"

${cloud_specific}

logger "Setting private key"
echo "${private_key}" | sudo tee /home/ubuntu/c1m/site.pem > /dev/null
sudo chmod 400 /home/ubuntu/c1m/site.pem

NODE_NAME="$(hostname)"
logger "Node name: $NODE_NAME"

METADATA_LOCAL_IP=`curl ${local_ip_url}`
logger "Local IP: $METADATA_LOCAL_IP"

logger "Configuring Consul default"
CONSUL_DEFAULT_CONFIG=/etc/consul.d/default.json
CONSUL_DATA_DIR=${data_dir}/consul/data

sudo mkdir -p $CONSUL_DATA_DIR
sudo chmod 0755 $CONSUL_DATA_DIR

sudo sed -i -- "s/{{ data_dir }}/$${CONSUL_DATA_DIR//\//\\\/}/g" $CONSUL_DEFAULT_CONFIG
sudo sed -i -- "s/{{ local_ip }}/$METADATA_LOCAL_IP/g" $CONSUL_DEFAULT_CONFIG
sudo sed -i -- "s/{{ datacenter }}/${datacenter}/g" $CONSUL_DEFAULT_CONFIG
sudo sed -i -- "s/{{ node_name }}/$NODE_NAME/g" $CONSUL_DEFAULT_CONFIG
sudo sed -i -- "s/{{ log_level }}/${consul_log_level}/g" $CONSUL_DEFAULT_CONFIG

logger "Removing Consul server config"
rm -f /etc/consul.d/consul_server.json

logger "Configuring Consul HDFS NameNode"
HDFS_NAMENODE_CONFIG=/etc/consul.d/hdfs_namenode.json

cat <<'EOF' | sudo tee $HDFS_NAMENODE_CONFIG > /dev/null
{
  "statsite_addr": "statsite.service.consul:8125",
  "statsite_prefix": "consul.hdfs_namenode",
  "service": {
    "name": "hdfs-namenode",
    "tags": ["{{ tags }}"]
  }
}
EOF

sudo sed -i -- "s/\"{{ tags }}\"/\"${provider}\", \"${region}\", \"${zone}\", \"${machine_type}\"/g" $HDFS_NAMENODE_CONFIG

echo $(date '+%s') | sudo tee -a /etc/consul.d/configured > /dev/null
sudo service consul start || sudo service consul restart

logger "Configuring Hadoop"
HADOOP_CORE_CONFIG=/opt/hadoop/etc/hadoop/core-site.xml
HADOOP_DATA_DIR=${data_dir}/hadoop/data

sudo mkdir -p $HADOOP_DATA_DIR
sudo chmod 0755 $HADOOP_DATA_DIR

sudo sed -i -- "s#{{ data_dir }}#$HADOOP_DATA_DIR#g" $HADOOP_CORE_CONFIG

logger "Formatting HDFS NameNode"
while read -r env; do export "$env"; done </etc/environment
/opt/hadoop/bin/hdfs namenode -format

# wait for consul to come up
sleep 30

logger "Starting HDFS NameNode"
sudo mkdir -p /etc/hadoop.d
echo $(date '+%s') | sudo tee -a /etc/hadoop.d/configured > /dev/null
sudo rm /etc/init/hdfs-namenode.override
sudo service hdfs-namenode start || sudo service hdfs-namenode restart

logger "Done"
