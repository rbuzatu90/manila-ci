#!/bin/bash
set -e

source /usr/local/src/manila-ci/jobs/utils.sh
ensure_branch_supported || exit 0

# Deploy devstack vm
/usr/local/src/manila-ci/jobs/deploy_devstack_vm.sh

# Run devstack
/usr/local/src/manila-ci/jobs/run_devstack.sh
