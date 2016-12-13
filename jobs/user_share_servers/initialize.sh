#!/bin/bash
set -e

source /usr/local/src/manila-ci/jobs/utils.sh
ensure_branch_supported || exit 0

# Deploy devstack vm
source /usr/local/src/manila-ci/jobs/deploy_devstack_vm.sh

# Update local.conf
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY  \
	"sed -i \"s/\(driver_handles_share_servers\).*/\1 = False/g\" /home/ubuntu/devstack/local.conf"
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY  \
    'sed -i "s/iniset \$TEMPEST_CONFIG share build_timeout 2400/iniset \$TEMPEST_CONFIG share build_timeout 2400 \niniset \$TEMPEST_CONFIG share multitenancy_enabled False/g" /home/ubuntu/bin/run_tests.sh'

# Run devstack
source /usr/local/src/manila-ci/jobs/run_devstack.sh

# Create the share server used by manila in this scenario
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY  \
    "source /home/ubuntu/keystonerc && /home/ubuntu/bin/create_share_server.sh" 6

# Ensure that the m-shr service is available or wait for it otherwise.
# Note that for this job type, the service becomes available only after
# the share server can be reached via WinRM.
run_ssh_cmd_with_retry ubuntu@$DEVSTACK_FLOATING_IP $DEVSTACK_SSH_KEY  \
    "source /home/ubuntu/keystonerc && /home/ubuntu/bin/check_manila.sh" 1
