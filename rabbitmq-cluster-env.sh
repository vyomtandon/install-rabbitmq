#!/bin/bash
#====================================================================
# rabbitmq_cluster_env.sh
#
# Linux RabbitMQ Cluster Script
#
# Maintainer Vyom Tandon <vyom.x.tandon.-nd@disney.com>
#====================================================================

#################################################################################################
# RabbitMQ Environment version Details
#################################################################################################

# RabbitMQ Ports
export ERL_EPMD_PORT=4369
export RABBITMQ_SSL_PORT=5671
export RABBITMQ_PORT=5672
export RABBITMQ_HTTP_PORT=15672
export RABBITMQ_DIST_PORT=25672

# Default Admin Password
export ADMIN_PWD=admin

# Version of Erlang to install
export ERLANG_VERSION=19.0.4-1

# RabbitMQ Plugins
export RABBITMQ_VERSION=3.6.6
export PLUGIN_BASE=v3.6.x
export AUTOCLUSTER_VERSION=0.6.1
export DELAYED_MESSAGE_VERSION=0.0.1
export MESSAGE_TIMESTAMP_VERSION=3.6.x-3195a55a
export TOP_VERSION=3.6.x-2d253d39

# RabbitMQ Configuration File
export RABBITMQ_CONFIG_FILE=rabbitmq.config

# Default Erlang Cookie
export ERLANG_COOKIE=WDPRRARABBITMQINSTALLATION

# CleanUp previous files.
rm -rf /etc/sysconfig/rabbitmq-join

/usr/bin/sh -c "/usr/bin/echo -n RABBITMQ_JOIN= > /etc/sysconfig/rabbitmq-join"

/usr/bin/sh -c "/usr/local/bin/aws ec2 describe-instances --filters 'Name=tag:Name,Values=$1*' --output text --query 'Reservations[*].Instances[*].PrivateDnsName' --region=$2 | tr '\n' ' ' >> /etc/sysconfig/rabbitmq-join"

export $(head -n 1 /etc/sysconfig/rabbitmq-join)

echo ${RABBITMQ_JOIN% *}

# get script path
export SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

/usr/bin/sh /root/opt/install-rabbitmq/rabbitmq_install.sh -ij ${RABBITMQ_JOIN%;*}