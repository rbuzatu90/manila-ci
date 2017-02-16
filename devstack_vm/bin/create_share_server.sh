#!/bin/bash

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
    nova --os-username manila --os-tenant-name service --os-password Passw0rd \
        boot ws2012r2 --image=ws2012r2 \
                      --flavor=100 \
                      --nic net-id=$NET_ID \
                      --user-data=/home/ubuntu/ssl/winrm_client_cert.pem \
                      --security-groups $MANILA_SERVICE_SECGROUP
    VM_OK=$?
    RETRIES=$(( $RETRIES -1 ))
done

