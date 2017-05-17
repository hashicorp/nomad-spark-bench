## Spark Load Test

This repository contains the infrastructure code to run a Spark load test to compare Spark performance on Nomad and YARN.

We leverage [Packer](https://www.packer.io/) and [Terraform](https://www.terraform.io/) to provision the infrastructure. Below are the instructions to provision the infrastructure.


### Provisioning Infrastructure

##### Step 0: Set Up Credentials

Create an SSH key for use with the cluster:

```
openssl genrsa -out cluster_ssh_key.pem 2048
chmod 600 cluster_ssh_key.pem
ssh-keygen -y -f cluster_ssh_key.pem > cluster_ssh_key.pub
```

The sections that follow assume that your Azure credentials are available in these environment variables:

```
export ARM_SUBSCRIPTION_ID=YOUR_SUBSCRIPTION_ID
export ARM_CLIENT_ID=YOUR_CLIENT_ID
export ARM_CLIENT_SECRET=YOUR_CLIENT_SECRET
export ARM_TENANT_ID=YOUR_TENANT_ID

export ARM_ENVIRONMENT=public
```

##### Step 1: Provision Disk Image Storage Account with Terraform

We're going to build a disk image using packer in the next step, and on Azure we first need a storage account to put the image in.

Apply [Terraform](https://www.terraform.io/) in the `terraform/_env/azure_images` directory.

```
cd terraform/_env/azure_images
terraform apply
cd -
```

##### Step 2: Build Disk Image with Packer

A disk image needs to be created which Terraform will use to provision VMs.

Run [Packer](https://www.packer.io/) with the resource group and storage account created in the previous step
and capture the OSDiskUri:

```
packer build \
    -var resource_group=$(terraform output -state=terraform/_env/azure_images/terraform.tfstate resource_group) \
    -var storage_account=$(terraform output -state=terraform/_env/azure_images/terraform.tfstate storage_account) \
    packer/azure.json \
    | tee >(awk '/^OSDiskUri: https:/ { print $2 > "packer/latest_disk_image.url" }')
```

At the end of the build, packer will output a number of URLs.
Copy the `OSDiskUri` to use in the next step.


##### Step 3: Provision Infrastructure with Terraform

To provision the infrastructure necessary to run the load test,
apply [Terraform](https://www.terraform.io/) in the `terraform/_env/azure_images` directory,
passing in the URI of the image generated in the previous step.

Note that while the Terraform Azure provisioner will read your client ID and secret from the environment variables set above,
we need to pass the client secret to the VMs we create, and we don't have a way to access it from within Terraform,
so we need to make it available explicitly.

To tweak the infrastructure size, update the Terraform variable(s) for the region(s) you're provisioning.

```
cd terraform/_env/azure
terraform get
TF_VAR_arm_client_secret=$ARM_CLIENT_SECRET terraform apply -var disk_image="$(cat ../../../packer/latest_disk_image.url)"
cd -
```

##

NOMAD_ADDR=http://nomad-server.service.consul:4646 ./run.sh nomad-args.txt nomad-0 1


## Scheduling with Nomad

Once your infrastructure is provisioned, grab a Nomad Server to `ssh` into from the output of the `terraform apply` or from the web console. Jot down the public IP of the Nomad server you're going to run these jobs from, you will need to later to gather your results.

Run the below commands to schedule your first job. This will schedule 5 docker containers on 5 different nodes using the `node_class` constraint. Each job contains a different number of tasks that will be scheduled by Nomad, the job types are defined below.

- [Docker Driver](https://www.nomadproject.io/docs/drivers/docker.html) (`classlogger_n_docker.nomad`)
  - Schedules n number of docker containers
- [Docker Driver](https://www.nomadproject.io/docs/drivers/docker.html) with Consul (`classlogger_n_consul_docker.nomad`)
  - Schedules n number of docker containers registering each container as a service with Consul
- [Raw Fork/Exec Driver](https://www.nomadproject.io/docs/drivers/raw_exec.html) (`classlogger_n_raw_exec.nomad`)
  - Schedules n number of tasks
- [Raw Fork/Exec Driver](https://www.nomadproject.io/docs/drivers/raw_exec.html) with Consul (`classlogger_n_consul_raw_exec.nomad`)
  - Schedules n number of tasks registering each task as a service with Consul

You can change the _job_ being run by modifying the `JOBSPEC` environment variable and change the _number of jobs_ being run by modifying the `JOBS` environment variables.

```
ssh ubuntu@NOMAD_SERVER_IP

cd /opt/nomad/jobs
sudo JOBSPEC=docker-classlogger-1.nomad JOBS=1 bench-runner /usr/local/bin/bench-nomad
```

To gather results, complete the [C1M Results](#c1m-results) steps after running each job. Before adding more nodes to your infrastructure, be sure to pull down the [Spawn Results](#spawn-results) locally so you can see how fast Terraform and GCE spun up each infrastructure size.

### Gather Results

To gather the results of the C1M challenge, follow the below instructions.

##### Spawn Results

Run the below commands from the Utility box to gather C1M spawn results.

```
consul exec 'scp -C -q -o StrictHostKeyChecking=no -i /home/ubuntu/c1m/site.pem /home/ubuntu/c1m/spawn/spawn.csv ubuntu@utility.service.consul:/home/ubuntu/c1m/spawn/$(hostname).file'

FILE=/home/ubuntu/c1m/spawn/$(date '+%s').csv && find /home/ubuntu/c1m/spawn/. -type f -name '*.file' -exec cat {} + >> $FILE && sed -i '1s/^/type,name,time\n/' $FILE
```

Make sure the `consul exec` command pulled in all of the spawn files by running `ls -1 | grep '.file' |  wc -l` and confirm the count matches your number of nodes. This command is idempotent and can be run multiple times. Below are some examples of how you can get live updates on Consul and Nomad agents, as well as running `consul-exec` until it has all necessary files.

```
# Live updates on Nomad agents
EXPECTED=5000 && CURRENT=0 && while [ $CURRENT -lt $EXPECTED ]; do CURRENT=$(nomad node-status | grep 'ready' |  wc -l); echo "Nomad nodes ready: $CURRENT/$EXPECTED"; sleep 10; done

# Live updates on Consul agents
EXPECTED=5009 && CURRENT=0 && while [ $CURRENT -lt $EXPECTED ]; do CURRENT=$(consul members | grep 'alive' |  wc -l); echo "Consul members alive: $CURRENT/$EXPECTED"; sleep 10; done

# Run consul exec until you have the number of spawn files you need
EXPECTED=5009 && CURRENT=0 && while [ $CURRENT -lt $EXPECTED ]; do consul exec 'scp -C -q -o StrictHostKeyChecking=no -i /home/ubuntu/c1m/site.pem /home/ubuntu/c1m/spawn/spawn.csv ubuntu@utility.service.consul:/home/ubuntu/c1m/spawn/$(hostname).file'; CURRENT=$(ls -1 /home/ubuntu/c1m/spawn | grep '.file' |  wc -l); echo "Spawn files: $CURRENT/$EXPECTED"; sleep 60; done
```

Run [spawn_results.sh](scripts/spawn_results.sh) locally after running all jobs for each node count to gather all C1M spawn results.

```
sh spawn_results.sh UTILITY_IP NODE_COUNT
```

##### C1M Results

Run [c1m_results.sh](scripts/c1m_results.sh) locally after running each job for each node count to gather all C1M performance results.

```
sh c1m_results.sh NOMAD_SERVER_IP UTILITY_IP NODE_COUNT JOB_NAME
```

### Nomad Join

Use the below `consul exec` commands to run a Nomad join operation on any subset of Nomad agents. This can be used to join servers, join clients to servers, or change the Nomad server cluster at which clients are pointing.

##### Join Nomad Servers

```
consul exec -datacenter gce-us-central1 -service nomad-server 'sudo /opt/nomad/nomad_join.sh "nomad-server?dc=gce-us-central1&passing" "server"'
consul exec -service nomad-server 'sudo /opt/nomad/nomad_join.sh "nomad-server?passing" "server"'
```

##### Join Nomad Client to Nomad Servers

```
consul exec -service nomad-client 'sudo /opt/nomad/nomad_join.sh "nomad-server?passing"'
```
