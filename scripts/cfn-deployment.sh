#!/bin/bash
# Internal Use Only
# Script to run Cloudformation Stack deployment
set -e

# AWS Cloudformation create stack, using unique TRAVIS BUILD ID and passing the previously created AMI_ID from Packer
echo "Deploy Cloudformation Stack - Build ID ${TRAVIS_BUILD_ID}"
aws cloudformation create-stack --stack-name ibm-mq-${TRAVIS_BUILD_ID} \
      --template-body file://./ibm-mq-master.template \
      --capabilities CAPABILITY_IAM --region eu-west-1 \
      --parameters ParameterKey=KeyPairName,ParameterValue=TravisBuildTemporary-${TRAVIS_BUILD_ID} \
      ParameterKey=QueueManagerName,ParameterValue='mqdev' \
      ParameterKey=AvailabilityZones,ParameterValue=\"eu-west-1a,eu-west-1b\" \
      ParameterKey=RemoteAccessCIDR,ParameterValue='195.212.29.0/24' \
      ParameterKey=Owner,ParameterValue='ibm.travis' \
      ParameterKey=InstanceName,ParameterValue="ibm-mq-${TRAVIS_BUILD_ID}" \
      ParameterKey=QSS3BucketName,ParameterValue='ibm-mq-quickstart' \
      ParameterKey=MQConsolePassword,ParameterValue='test1234' \
      ParameterKey=MQAdminPassword,ParameterValue='test1234' \
      ParameterKey=MQAppPassword,ParameterValue='test1234' \
      ParameterKey=LicenseFileURL,ParameterValue=''

# wait until cloudformation stack exists
# VPC Stack
echo ""
echo "Wait for VPC Stack to Complete"
sleep 1m
VPC_STACK=$(aws cloudformation describe-stacks --query 'Stacks[0].StackName' --output text)
aws cloudformation wait stack-create-complete --stack-name ${VPC_STACK}
echo "VPC Stack Complete"
echo ""

# Bastion Stack
echo "Wait for Bastion Stack to Complete"
sleep 1m
BASTION_STACK=$(aws cloudformation describe-stacks --query 'Stacks[0].StackName' --output text)
aws cloudformation wait stack-create-complete --stack-name ${BASTION_STACK}
echo "Bastion Stack Complete"
echo ""

# MQ Stack
echo "Wait for MQ Stack to Complete"
sleep 1m
MQ_STACK=$(aws cloudformation describe-stacks --query 'Stacks[0].StackName' --output text)
aws cloudformation wait stack-create-complete --stack-name ${MQ_STACK}
echo "MQ Stack Complete"
echo ""

# Wait for master stack to complete
echo "Wait for Main Stack to Complete"
aws cloudformation wait stack-create-complete --stack-name ibm-mq-${TRAVIS_BUILD_ID}
echo "MQ Stack Complete"
echo ""

# list resources deployed by cloudformation
echo "List Resources"
echo ""
aws cloudformation list-stack-resources --stack-name ibm-mq-${TRAVIS_BUILD_ID}
echo ""
# Get current instance and output id to var
INSTANCE_ID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=ibm-mq-${TRAVIS_BUILD_ID} --output text --query 'Reservations[0].Instances[0].InstanceId')

# Get current loadbalancer and output DNS name to var
ELB_DNS=$(aws elb describe-load-balancers --load-balancer-names ibm-mq-quickstart-elb-mqdev --output text --query 'LoadBalancerDescriptions[0].DNSName')

# wait until instance is up and running and returns status ok
echo "Check instance status"
aws ec2 wait instance-status-ok --instance-ids

# check ports are forwarded to load balancer
echo "Test Ports on Load Balancer"
nc -v -z ${ELB_DNS} 1414
nc -v -z ${ELB_DNS} 9443

# curl REST API endpoints
echo "GET current installation attributes"
curl -k "https://${ELB_DNS}:9443/ibmmq/rest/v1/installation/installation1?attributes=*" -u mqconsoleadmin:test1234 -c ./cookiejar.txt

echo ""
echo "GET current test Queue Manager attributes and status"
curl -k "https://${ELB_DNS}:9443/ibmmq/rest/v1/qmgr/mqdev?attributes=*&status=*" -u mqconsoleadmin:test1234 -c ./cookiejar.txt

# delete current cloudformation stack and remove all resources
echo ""
echo "Delete master stack"
aws cloudformation delete-stack --stack-name ibm-mq-${TRAVIS_BUILD_ID}
echo ""

# delete temporary keypair
echo "Delete temporary keypair"
aws ec2 delete-key-pair --key-name TravisBuildTemporary-${TRAVIS_BUILD_ID}
echo ""

# wait until cloudformation stack is deleted
echo "Wait for MQ Stack to delete"
aws cloudformation wait stack-delete-complete --stack-name ${MQ_STACK}
echo ""
echo "Wait for Bastion Stack to delete"
aws cloudformation wait stack-delete-complete --stack-name ${BASTION_STACK}
echo ""
echo "Wait for VPC Stack to delete"
aws cloudformation wait stack-delete-complete --stack-name ${VPC_STACK}
echo ""
echo "Wait for VPC Stack to delete"
aws cloudformation wait stack-delete-complete --stack-name ibm-mq-${TRAVIS_BUILD_ID}
echo ""
echo "Test Deployment Complete - All Artifacts Removed"
