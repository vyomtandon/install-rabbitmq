#!/bin/bash
#====================================================================
# rabbitmq_cluster_env.sh
#
# Linux RabbitMQ Cluster Script
#
# Maintainer Vyom Tandon <vyom.x.tandon.-nd@disney.com>
#====================================================================

/usr/bin/sh -c "/usr/bin/echo -n RABBITMQ_JOIN= > /etc/sysconfig/rabbitmq-join"

/usr/bin/sh -c "/usr/local/bin/aws ec2 describe-instances --filters 'Name=tag:Name,Values=gam-ats-rmq-latest*' --output text --query 'Reservations[*].Instances[*].PrivateDnsName' --region=us-east-1 | tr '\n' ';' >> /etc/sysconfig/rabbitmq-join"

export $(head -n 1 /etc/sysconfig/rabbitmq-join)

# get script path
export SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

/usr/bin/sh $SCRIPT_PATH/rabbitmq_install.sh -i -c ZTXOCZYZWBCFLBPOBEUQ -j rabbit@${RABBITMQ_JOIN%;*}
