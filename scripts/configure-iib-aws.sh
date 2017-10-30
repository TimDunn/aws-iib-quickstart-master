#!/bin/bash
# -*- mode: sh -*-
# (C) Copyright IBM Corporation 2017
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ "$#" -lt 3 ]; then
  echo "Usage: configure-iib-aws iib-node-name efs-id aws-region"
  exit 1
fi

set -e

configure_os_user()
{
  # The group ID of the user to configure
  local -r GROUP_NAME=$1
  # Name of environment variable containing the user name
  local -r USER_VAR=$2
  # Name of environment variable containing the password
  local -r PASSWORD=$3
  # Home directory for the user
  local -r HOME=$4
  # Determine the login name of the user (assuming it exists already)

  # if user does not exist
  if ! id ${!USER_VAR} 2>1 > /dev/null; then
    # create
    useradd --gid ${GROUP_NAME} --home ${HOME} ${!USER_VAR}
  fi
  # Change the user's password (if set)
  if [ ! "${!PASSWORD}" == "" ]; then
    echo ${!USER_VAR}:${!PASSWORD} | chpasswd
  fi
}

IIB_NODE_NAME=$1
IIB_INTEGRATION_SERVER_NAME=$2
IIB_FILE_SYSTEM=$3
AWS_REGION=$4
AWS_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
IIB_CONSOLE_USERNAME=${5:-"iibconsoleadmin"}
IIB_CONSOLE_PASSWORD=${6}
IIB_ADMIN_NAME="iibadmin"
IIB_ADMIN_PASSWORD=${7:-""}
IIB_APP_NAME="iibapp"
IIB_APP_PASSWORD=${8:-""}

# Configure fstab to mount the EFS file system as boot time
echo "${AWS_ZONE}.${IIB_FILE_SYSTEM}.efs.${AWS_REGION}.amazonaws.com:/ /var/mqsi nfs4 defaults 0 2" >> /etc/fstab

# Mount the file system
mount /var/mqsi

# Create the queue manager if it doesn't already exist
# Copy the mqwebuser configuration for the mqweb console

# Create/update the MQ directory structure under the mounted directory
if [ ! -d "/var/mqm/qmgrs/${MQ_QMGR_NAME}" ]; then
  /opt/mqm/bin/amqicdir -i -f
  /opt/mqm/bin/amqicdir -s -f

  su mqm -c "crtmqm -q ${MQ_QMGR_NAME}" || exit 2

  # Set Username and Password for MQ Console User
  sudo sed -i "s/<USERNAME>/${IIB_CONSOLE_USERNAME}/g" /usr/local/bin/starter-registry.xml
  sudo sed -i "s/<PASSWORD>/${IIB_CONSOLE_PASSWORD}/g" /usr/local/bin/starter-registry.xml
fi

# Set needed variables to point to various MQ directories
DATA_PATH=`dspmqver -b -f 4096`
INSTALLATION=`dspmqver -b -f 512`

echo "Configuring app user"
if ! getent group mqclient; then
  # Group doesn't exist already
  groupadd mqclient
fi

configure_os_user mqclient MQ_APP_NAME MQ_APP_PASSWORD /home/app

echo "Configuring admin user"
configure_os_user mqm MQ_ADMIN_NAME MQ_ADMIN_PASSWORD /home/admin

# Add a systemd drop-in to create a dependency on the mount point
mkdir -p /etc/systemd/system/mq@${MQ_QMGR_NAME}.service.d
cat << EOF > /etc/systemd/system/mq@${MQ_QMGR_NAME}.service.d/mount-var-mqm.conf
[Unit]
RequiresMountsFor=/var/mqm
EOF

systemctl daemon-reload

# Enable the systemd services to run at boot time
systemctl enable mq@${MQ_QMGR_NAME}
systemctl enable mq-console-setup
systemctl enable mq-console
systemctl enable mq-health-aws@${MQ_QMGR_NAME}

# Start the systemd services
systemctl start mq@${MQ_QMGR_NAME}
systemctl start mq-console-setup
systemctl start mq-console
systemctl start mq-health-aws@${MQ_QMGR_NAME}

runmqsc ${MQ_QMGR_NAME} < /etc/config.mqsc
