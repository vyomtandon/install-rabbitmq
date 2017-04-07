#!/bin/bash
#====================================================================
# rabbitmq_cluster_env.sh
#
# Linux RabbitMQ Cluster Script
#
# Maintainer Vyom Tandon <vyom.x.tandon.-nd@disney.com>
#====================================================================

/usr/bin/sh -c "/usr/bin/echo -n RABBITMQ_JOIN= > /etc/sysconfig/rabbitmq-join"
/usr/bin/sh -c "/usr/local/bin/aws ec2 describe-instances --filters 'Name=tag:Name,Values=${cluster_name}*' --output text --query 'Reservations[*].Instances[*].PrivateIpAddress' --region=${region} | tr '\n' ';' >> /etc/sysconfig/rabbitmq-join"
/usr/bin/sh ./install_rabbitmq.sh -i -c ZTXOCZYZWBCFLBPOBEUQ -j rabbit@$RABBITMQ_JOIN