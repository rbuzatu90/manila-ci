#!/bin/bash
#
hyperv_node=$1
# Loading all the needed functions
source /usr/local/src/manila-ci/jobs/utils.sh

# Loading parameters
source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.manila.txt

export LOG_DIR='C:\Openstack\logs\'

# building HyperV node
echo $hyperv_node
join_hyperv $WIN_USER $WIN_PASS $hyperv_node 
