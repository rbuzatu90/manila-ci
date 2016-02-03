#!/bin/bash

exec_with_retry2 () {
    MAX_RETRIES=$1
    INTERVAL=$2

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        echo `date -u +%H:%M:%S`
        # echo "Running: ${@:3}"
        eval '${@:3}' || EXIT=$?
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
    CMD=${@:3}
    MAX_RETRIES=$1
    INTERVAL=$2

    exec_with_retry2 $MAX_RETRIES $INTERVAL $CMD
}

run_wsmancmd_with_retry () {
    HOST=$1
    USERNAME=$2
    PASSWORD=$3
    CMD=${@:4}

    exec_with_retry 10 5 "python /home/jenkins-slave/tools/wsman.py -U https://$HOST:5986/wsman -u $USERNAME -p $PASSWORD $CMD"
}

wait_for_listening_port () {
    HOST=$1
    PORT=$2
    TIMEOUT=$3
    exec_with_retry 50 5 "nc -z -w$TIMEOUT $HOST $PORT"
}

run_ssh_cmd () {
    SSHUSER_HOST=$1
    SSHKEY=$2
    CMD=$3
    ssh -t -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i $SSHKEY $SSHUSER_HOST "$CMD" 
}

run_ssh_cmd_with_retry () {
    SSHUSER_HOST=$1
    SSHKEY=$2
    CMD=$3
    INTERVAL=$4
    MAX_RETRIES=10

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
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
    HOST=$1
    USERNAME=$2
    PASSWORD=$3
    CMD=${@:4}
    PS_EXEC_POLICY='-ExecutionPolicy RemoteSigned'

    run_wsmancmd_with_retry $HOST $USERNAME $PASSWORD "powershell $PS_EXEC_POLICY $CMD"
}


join_hyperv (){
    set +e
    WIN_USER=$1
    WIN_PASS=$2
    URL=$3

    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned Remove-Item -Recurse -Force c:\Openstack\manila-ci"
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "git clone -b cambridge https://github.com/cloudbase/manila-ci C:\Openstack\manila-ci"
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\teardown.ps1"
    
    set -e
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\EnsureOpenStackServices.ps1 $WIN_USER $WIN_PASS"
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\manila-ci\HyperV\scripts\create-environment.ps1 -devstackIP $FIXED_IP"
}

teardown_hyperv () {
    WIN_USER=$1
    WIN_PASS=$2
    URL=$3

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
