#!/bin/bash
set -e

source /usr/local/src/manila-ci/jobs/utils.sh
ensure_branch_supported || exit 0

# Deploy devstack vm
/usr/local/src/manila-ci/jobs/deploy_devstack_vm.sh

source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.manila.txt

# Run devstack
/usr/local/src/manila-ci/jobs/run_devstack.sh

run_ssh_cmd_with_retry ubuntu@$FIXED_IP $DEVSTACK_SSH_KEY \
    'source /home/ubuntu/keystonerc; NOVA_COUNT=$(nova service-list | grep nova-compute | grep -c -w up); if [ "$NOVA_COUNT" != 1 ];then nova service-list; exit 1;fi' 12 

if [ "$ZUUL_BRANCH" == "master" ]; then
    run_ssh_cmd_with_retry ubuntu@$FIXED_IP $DEVSTACK_SSH_KEY \
        "url=\$(grep transport_url /etc/nova/nova-dhcpbridge.conf | awk '{print \$3}'); nova-manage cell_v2 simple_cell_setup --transport-url \$url >> /opt/stack/logs/screen/create_cell.log"
fi

