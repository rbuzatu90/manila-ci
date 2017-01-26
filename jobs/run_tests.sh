#!/bin/bash

source /usr/local/src/manila-ci/jobs/utils.sh
ensure_branch_supported || exit 0

export FAILURE=0
echo "Running tests"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$FIXED_IP "source /home/ubuntu/keystonerc && /home/ubuntu/bin/run_tests.sh" 
