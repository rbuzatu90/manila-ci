#!/bin/bash

echo "Collecting logs"

source /usr/local/src/manila-ci/jobs/utils.sh

set -x

source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.manila.txt

#!/bin/bash
jen_date=$(date +%d/%m/%Y-%H:%M)
set +e

ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i /home/jenkins-slave/tools/admin-msft.pem ubuntu@$DEVSTACK_FLOATING_IP "mkdir -p /openstack/logs/${hyperv_node%%[.]*}"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i /home/jenkins-slave/tools/admin-msft.pem ubuntu@$DEVSTACK_FLOATING_IP "sudo chown -R nobody:nogroup /openstack/logs"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i /home/jenkins-slave/tools/admin-msft.pem ubuntu@$DEVSTACK_FLOATING_IP "sudo chmod -R 777 /openstack/logs"
python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\export-eventlog.ps1'
python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned cp -Recurse -Container  C:\OpenStack\Log\Eventlog\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv_node%%[.]*}'\'
python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned Copy-Item -Recurse C:\OpenStack\Log\* \\'$DEVSTACK_FLOATING_IP'\openstack\logs\'${hyperv_node%%[.]*}'\'

if [ "$IS_DEBUG_JOB" != "yes" ] || [ -z '$IS_DEBUG_JOB' ]; then
	echo "Detaching and cleaning Hyper-V node"
	python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u administrator -p H@rd24G3t "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\teardown.ps1"
fi

if [ -z '$ZUUL_CHANGE' ] || [ -z '$ZUUL_PATCHSET' ]; then
    echo 'Missing parameters!'
    echo "ZUUL_CHANGE=$ZUUL_CHANGE"
    echo "ZUUL_PATCHSET=$ZUUL_PATCHSET"
    exit 1
fi

if [ "$IS_DEBUG_JOB" != "yes" ];then
    LOG_ARCHIVE_DIR="/srv/logs/manila/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
else
    TIMESTAMP=$(date +%d-%m-%Y_%H-%M)
    LOG_ARCHIVE_DIR="/srv/logs/debug/manila/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/$TIMESTAMP"
fi

function ssh_cmd_logs_sv {
    local CMD=$1
    ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld $CMD
}

function log_unsupported_branch {
    echo "The Windows SMB Manila driver is supported only on OpenStack Liberty or later." > /tmp/results.txt
    echo ZUUL_BRANCH=$ZUUL_BRANCH >> /tmp/results.txt
    scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY /tmp/results.txt logs@logs.openstack.tld:$LOG_ARCHIVE_DIR/results.txt
    rm /tmp/results.txt
}

ensure_branch_supported || (log_unsupported_branch && exit 0)

ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "/home/ubuntu/bin/collect_logs.sh $IS_DEBUG_JOB"

echo "Creating logs destination folder"
ssh_cmd_logs_sv "if [ ! -d $LOG_ARCHIVE_DIR ]; then mkdir -p $LOG_ARCHIVE_DIR; else rm -rf $LOG_ARCHIVE_DIR/*; fi"

echo "Downloading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/aggregate.tar.gz "aggregate-$NAME.tar.gz"

#echo "Before gzip:"
#ls -lia `dirname $CONSOLE_LOG`

echo "GZIP:"
gzip -v9 $CONSOLE_LOG

#echo "After gzip:"
#ls -lia `dirname $CONSOLE_LOG`

echo "Uploading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "aggregate-$NAME.tar.gz" logs@logs.openstack.tld:$LOG_ARCHIVE_DIR/aggregate-logs.tar.gz
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY $CONSOLE_LOG.gz logs@logs.openstack.tld:$LOG_ARCHIVE_DIR/console.log.gz && rm -f $CONSOLE_LOG*

echo "Extracting logs"
ssh_cmd_logs_sv "tar -xzf $LOG_ARCHIVE_DIR/aggregate-logs.tar.gz -C $LOG_ARCHIVE_DIR"

echo "Fixing permissions on all log files"
ssh_cmd_logs_sv "chmod a+rx -R $LOG_ARCHIVE_DIR"

#Checking the number of iSCSI targets and portals before clean-up
python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS 'powershell $targets = gwmi -ns root/microsoft/windows/storage -class msft_iscsitarget; Write-Host "[PRE_CLEAN] $env:computername has $targets.count" iSCSI targets'
python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS 'powershell $targets = gwmi -ns root/microsoft/windows/storage -class msft_iscsitargetportal; Write-Host "[PRE_CLEAN] $env:computername has $targets.count" iSCSI portals'

echo `date -u +%H:%M:%S` "Started cleaning iSCSI targets and portals"

nohup python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS 'powershell $targets = gwmi -ns root/microsoft/windows/storage -class msft_iscsitarget; $ErrorActionPreference = "Continue"; $targets[0].update();' &
pid_clean_targets_hyperv=$!

nohup python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS  'powershell $targets = gwmi -ns root/microsoft/windows/storage -class msft_iscsitargetportal; foreach ($target in $targets) {$target.remove()}' &
pid_clean_portals_hyperv=$!

wait $pid_clean_portals_hyperv
wait $pid_clean_targets_hyperv

echo `date -u +%H:%M:%S` "Finished cleaning iSCSI targets and portals"

#Checking the number of iSCSI targets and portals after clean-up
python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS 'powershell $targets = gwmi -ns root/microsoft/windows/storage -class msft_iscsitarget; Write-Host "[POST_CLEAN] $env:computername has $targets.count" iSCSI targets'
python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS 'powershell $targets = gwmi -ns root/microsoft/windows/storage -class msft_iscsitargetportal; Write-Host "[POST_CLEAN] $env:computername has $targets.count" iSCSI portals'

# Restarting MSiSCSI service 
python /home/jenkins-slave/tools/wsman.py -U https://$hyperv_node:5986/wsman -u $WIN_USER -p $WIN_PASS 'powershell restart-service msiscsi; iscsicli listtargets; iscsicli listtargetportals'

echo `date -u +%H:%M:%S`
set +x
