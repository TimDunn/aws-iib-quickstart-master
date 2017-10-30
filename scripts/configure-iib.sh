#!/bin/bash\n",
MOUNT_POINT=/var/mqsi

mount ${MOUNT_POINT}

IIB_NODE_NAME=$1
IIB_INTEGRATION_SERVER_NAME=$2

# Recommended: Create the iib user ID with a fixed UID and group, so that the
# file permissions work between different images
useradd --uid 2345 --gid mqbrkrs --home-dir /var/mqsi iib
usermod -G mqbrkrs root

# Configure file limits for the iib user
echo \"iib       hard  nofile     10240\" >> /etc/security/limits.conf
echo \"iib       soft  nofile     10240\" >> /etc/security/limits.conf,
echo \". /opt/ibm/iib-10.0.0.10/server/bin/mqsiprofile\" >> ~iib/.bash_profile
chown iib.mqbrkrs ~iib/.bash_profile
sudo su - iib -c \"mqsicreatebroker ${IIB_NODE_NAME}\"
sudo su - iib -c \"mqsichangebroker ${IIB_NODE_NAME} -f all\
sudo su - iib -c \"mqsistart ${IIB_NODE_NAME}\
sudo su - iib -c \"mqsicreateexecutiongroup ${IIB_NODE_NAME} -e ${IIB_INTEGRATION_SERVER_NAME}\
echo \"Integration Node is ${IIB_NODE_NAME}\

IIB_NODE_CONF=/etc/init/mqsistart-${IIB_NODE_NAME}.conf
cp /tmp/iib-upstart-mqsistart.conf ${IIB_NODE_CONF}\
sed -i \"s/%NODE%/${IIB_NODE_NAME}/\" ${IIB_NODE_CONF}\
IIB_NODE_CONF=/etc/init/mqsistop-${IIB_NODE_NAME}.conf
cp /tmp/iib-upstart-mqsistop.conf ${IIB_NODE_CONF}
sed -i \"s/%NODE%/${IIB_NODE_NAME}/\" ${IIB_NODE_CONF}
initctl reload-configuration
initctl start mqsistart-${IIB_NODE_NAME}
