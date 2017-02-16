#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. $DIR/utils.sh

# TODO(lpetrut): remove hardcoded stuff
MANILA_SERVICE_SECGROUP="manila-service"
NET_ID=$(neutron net-list | grep private | awk '{print $2}')
neutron net-update --shared=True private

nova --os-username manila --os-tenant-name service --os-password Passw0rd \
   secgroup-delete $MANILA_SERVICE_SECGROUP
nova --os-username manila --os-tenant-name service --os-password Passw0rd \
   secgroup-create $MANILA_SERVICE_SECGROUP $MANILA_SERVICE_SECGROUP

echo "Adding security rules to the $MANILA_SERVICE_SECGROUP security group"
nova --os-username manila --os-tenant-name service --os-password Passw0rd \
    secgroup-add-rule $MANILA_SERVICE_SECGROUP tcp 1 65535 0.0.0.0/0
nova --os-username manila --os-tenant-name service --os-password Passw0rd \
    secgroup-add-rule $MANILA_SERVICE_SECGROUP udp 1 65535 0.0.0.0/0

VM_OK=1
RETRIES=5
while [ $VM_OK -ne 0 ] && [ $RETRIES -ne 0 ]; do
    VMID=$(nova --os-username manila --os-tenant-name service --os-password Passw0rd \
        boot ws2012r2 --image=ws2012r2 \
                      --flavor=100 \
                      --nic net-id=$NET_ID \
                      --user-data=/home/ubuntu/ssl/winrm_client_cert.pem \
                      --security-groups $MANILA_SERVICE_SECGROUP | \
                      awk '{if (NR == 21) {print $4}}')

    FIXED_IP=$(nova show "$VMID" | grep "private network" | awk '{print $5}')
    export FIXED_IP="${FIXED_IP//,}"

    COUNT=1
    while [ -z "$FIXED_IP" ]; do
        if [ $COUNT -lt 10 ]; then
            sleep 15
            FIXED_IP=$(nova show "$VMID" | grep "private network" | awk '{print $5}')
            export FIXED_IP="${FIXED_IP//,}"
            COUNT=$(($COUNT + 1))
        else
            echo "Failed to get fixed IP using nova show $VMID"
            echo "Trying to get the IP from console-log and port-list"
            FIXED_IP1=`nova console-log $VMID | grep "ci-info" | grep "eth0" | grep "True" | awk '{print $7}'`
            echo "From console-log we got IP: $FIXED_IP1"
            FIXED_IP2=`neutron port-list -D -c device_id -c fixed_ips | grep $VMID | awk '{print $7}' | tr -d \" | tr -d }`
            echo "From neutron port-list we got IP: $FIXED_IP2"
            if [[ -z "$FIXED_IP1" || -z "$FIXED_IP2" ||  "$FIXED_IP1" != "$FIXED_IP2" ]]; then
                echo "Failed to get fixed IP"
                echo "nova show output:"
                nova show "$VMID"
                echo "nova console-log output:"
                nova console-log "$VMID"
                echo "neutron port-list output:"
                neutron port-list -D -c device_id -c fixed_ips | grep $VMID
                exit 1
            else
                export FIXED_IP=$FIXED_IP1
            fi
        fi
    done
    sleep 60
    echo "Probing for connectivity on IP $FIXED_IP"
    set +e
    wait_for_listening_port $FIXED_IP 22 30
    status=$?
    set -e
    if [ $status -eq 0 ]; then
        VM_OK=0
    echo "VM connectivity OK"
    else
    echo "VM connectivity NOT OK, rebooting VM"
        nova reboot "$VMID"
        sleep 120
        set +e
        wait_for_listening_port $FIXED_IP 22 30
        status=$?
        set -e
        if [ $status -eq 0 ]; then
            VM_OK=0
            echo "VM connectivity OK"
        else
            echo "nova console-log $VMID:"; nova console-log "$VMID"; echo "Failed listening for ssh port on devstack"
            echo "Deleting VM $VMID"
            nova delete $VMID
        fi
    fi

    RETRIES=$(( $RETRIES -1 ))
done

