#!/bin/bash

exec_with_retry2 () {
    local MAX_RETRIES=$1
    local INTERVAL=$2
    local VERBOSE=$3

    local COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        local EXIT=0
        if [ $VERBOSE == 'verbose' ]; then
            echo `date -u +%H:%M:%S`
        fi
        # echo "Running: ${@:3}"
        eval '${@:4}' || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
    let COUNTER=COUNTER+1

        if [ -n "$INTERVAL" ]; then
            sleep $INTERVAL
        fi
    done
    return $EXIT
}

exec_with_retry () {
    local CMD=${@:3}
    local MAX_RETRIES=$1
    local INTERVAL=$2

    exec_with_retry2 $MAX_RETRIES $INTERVAL 'verbose' $CMD
}

run_wsmancmd_with_retry () {
    local HOST=$1
    local USERNAME=$2
    local PASSWORD=$3
    local CMD=${@:4}

    exec_with_retry 10 5 "python /home/jenkins-slave/tools/wsman.py -U https://$HOST:5986/wsman -u $USERNAME -p $PASSWORD $CMD"
}

wait_for_listening_port () {
    local HOST=$1
    local PORT=$2
    local TIMEOUT=$3
    exec_with_retry 50 5 "nc -z -w$TIMEOUT $HOST $PORT"
}

run_ssh_cmd () {
    local SSHUSER_HOST=$1
    local SSHKEY=$2
    local CMD=$3
    ssh -t -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i $SSHKEY $SSHUSER_HOST "$CMD" 
}

run_ssh_cmd_with_retry () {
    local SSHUSER_HOST=$1
    local SSHKEY=$2
    local CMD=$3
    local INTERVAL=$4
    local MAX_RETRIES=10

    local COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        local EXIT=0
        run_ssh_cmd $SSHUSER_HOST $SSHKEY "$CMD" || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
        let COUNTER=COUNTER+1

        if [ -n "$INTERVAL" ]; then
            sleep $INTERVAL
        fi
    done
    return $EXIT
}

run_ps_cmd_with_retry () {
    local HOST=$1
    local USERNAME=$2
    local PASSWORD=$3
    local CMD=${@:4}
    local PS_EXEC_POLICY='-ExecutionPolicy RemoteSigned'

    run_wsmancmd_with_retry $HOST $USERNAME $PASSWORD "powershell $PS_EXEC_POLICY $CMD"
}


join_hyperv (){
    set +e
    local WIN_USER=$1
    local WIN_PASS=$2
    local URL=$3

    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS '"powershell -ExecutionPolicy RemoteSigned Remove-Item -Recurse -Force c:\Openstack\manila-ci >>\\'$FIXED_IP'\openstack\logs\create-environment-'$URL'.log 2>&1"'
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS '"git clone -b cambridge https://github.com/cloudbase/manila-ci C:\Openstack\manila-ci >>\\'$FIXED_IP'\openstack\logs\create-environment-'$URL'.log 2>&1"'
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\teardown.ps1' 
    
    set -e
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS '"powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\EnsureOpenStackServices.ps1 '$WIN_USER' '$WIN_PASS' >>\\'$FIXED_IP'\openstack\logs\create-environment-'$URL'.log 2>&1"'
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS '"powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\create-environment.ps1 -devstackIP '$FIXED_IP' >>\\'$FIXED_IP'\openstack\logs\create-environment-'$URL'.log 2>&1"'
}

post_build_hyperv (){
    local WIN_USER=$1
    local WIN_PASS=$2
    local URL=$3
    local WIN_IMG_ID=$4
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\prepare_windows_img.ps1 $WIN_IMG_ID"
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS '"powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\post-build-restart-services.ps1"'
}

teardown_hyperv () {
    local WIN_USER=$1
    local WIN_PASS=$2
    local URL=$3

    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\teardown.ps1"
}

ensure_branch_supported () {
    if [ $ZUUL_BRANCH = "stable/juno" ] || [ $ZUUL_BRANCH = "stable/kilo" ]
    then
        echo "The Windows SMB Manila driver is supported only on OpenStack Liberty or later."
        echo ZUUL_BRANCH=$ZUUL_BRANCH
        return 1
    fi
}
