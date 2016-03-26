## Nomad C1M Challenge

This repository contains the infrastructure code necessary to run the [Million Container Challenge](https://hashicorp.com/c1m.html) using [HashiCorp's Nomad](https://www.nomadproject.io/) on [Google's Compute Engine Cloud](https://cloud.google.com/compute/) or [Amazon Web Services](http://aws.amazon.com/).

We leverage [Packer](https://www.packer.io/) and [Terraform](https://www.terraform.io/) to provision the infrastructure. Below are the instructions to provision the infrastructure.

### Build Artifacts with Packer

Artifacts need to first be created for Terraform to provision. This can be accomplished by running the below commands in the [packer/.](packer) directory. You can alternatively build these images locally by running the `packer build` command instead of building them in Atlas with `packer push`.

From the root directory of this repository, run the below commands to build your images with [Packer](https://www.packer.io/).

##### GCE

**If you're using GCE** you will need to get an [`account.json`](https://www.packer.io/docs/builders/googlecompute.html) file from GCE and place it in the root of this repository.

```
cd packer

export ATLAS_USERNAME=YOUR_ATLAS_USERNAME
export GCE_PROJECT_ID=YOUR_GOOGLE_PROJECT_ID
export GCE_DEFAULT_ZONE=us-central1-a
export GCE_SOURCE_IMAGE=ubuntu-1404-trusty-v20160114e

packer push gce_utility.json
packer push gce_consul_server.json
packer push gce_nomad_server.json
packer push gce_nomad_client.json
```

##### AWS

```
cd packer

export ATLAS_USERNAME=YOUR_ATLAS_USERNAME
export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-east-1
export AWS_SOURCE_AMI=ami-9a562df2

packer push aws_utility.json
packer push aws_consul_server.json
packer push aws_nomad_server.json
packer push aws_nomad_client.json
```

### Provision Infrastructure with Terraform

To provision the infrastructure necessary for C1M, run the below Terraform commands. If you want to provision locally rather than in Atlas, use the `terraform apply` command instead of `terraform push`.

From the root directory of this repository, run the below commands to provision your infrastructure with [Terraform](https://www.terraform.io/).

You only need to run the `terraform remote config` command once.

##### GCE

**If you're using GCE** you will need to get an [`account.json`](https://www.terraform.io/docs/providers/google/) file from GCE and place it in the directory you're running Terraform commands from (`terraform/_env/gce`).

```
cd terraform/_env/gce

export ATLAS_USERNAME=YOUR_ATLAS_USERNAME
export ATLAS_TOKEN=YOUR_ATLAS_TOKEN
export ATLAS_ENVIRONMENT=c1m-gce

terraform remote config -backend-config name=$ATLAS_USERNAME/$ATLAS_ENVIRONMENT # Only need to run this command once
terraform get
terraform push -name $ATLAS_USERNAME/$ATLAS_ENVIRONMENT -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"
```

##### AWS

```
cd terraform/_env/aws

export ATLAS_USERNAME=YOUR_ATLAS_USERNAME
export ATLAS_TOKEN=YOUR_ATLAS_TOKEN
export ATLAS_ENVIRONMENT=c1m-aws

terraform remote config -backend-config name=$ATLAS_USERNAME/$ATLAS_ENVIRONMENT # Only need to run this command once
terraform get
terraform push -name $ATLAS_USERNAME/$ATLAS_ENVIRONMENT -var "atlas_token=$ATLAS_TOKEN" -var "atlas_username=$ATLAS_USERNAME"
```

To tweak the infrastructure size, update the Terraform variable(s) for the region(s) you're provisioning.

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
```

##### Join Nomad Client to Nomad Servers

```
consul exec -datacenter gce-us-central1 -service nomad-client 'sudo /opt/nomad/nomad_join.sh "nomad-server?dc=gce-us-central1&passing"'
```
