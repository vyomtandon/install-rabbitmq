#!/bin/bash
#====================================================================
# install_rabbitmq.sh
#
# Linux RabbitMQ Auto Install Script
#
# Maintainer Vyom Tandon <vyom.x.tandon.-nd@disney.com>
#====================================================================

echo "This script has been specifically written for RHEL/CentOS environment"
echo ""

if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script!"
    exit 1
fi

# defind functions
msg() {
    printf '%b\n' "$1" >&2
}

success() {
    msg "\33[32m[✔]\33[0m ${1}${2}"
}

error() {
    msg "\33[31m[✘]\33[0m ${1}${2}"
    exit 1
}

program_exists() {
    command -v $1 >/dev/null 2>&1
}

function open_rabbitmq_ports() {
    if program_exists firewall-cmd; then
        if [ -n "$(service firewalld status 2>/dev/null | grep running)" ]; then
            firewall-cmd -q --permanent \
                --add-port={$RABBITMQ_PORT/tcp,$RABBITMQ_HTTP_PORT/tcp,$ERL_EPMD_PORT/tcp,$RABBITMQ_DIST_PORT/tcp}
            firewall-cmd -q --reload
            firewall-cmd -q --query-port $RABBITMQ_PORT/tcp || return 1
            firewall-cmd -q --query-port $RABBITMQ_HTTP_PORT/tcp || return 1
            firewall-cmd -q --query-port $ERL_EPMD_PORT/tcp || return 1
            firewall-cmd -q --query-port $RABBITMQ_DIST_PORT/tcp || return 1
        fi
    fi
}

function erase_rabbitmq() {
    rpm -e rabbitmq-server
}

function update_rabbitmq_package() {
    # install required package
    program_exists wget || yum -y install wget >/dev/null 2>&1

    # install erlang rpm
    if [ ! -f "$ERLANG_RPM_PATH" ]; then
        msg "WARNING: $ERLANG_RPM_PATH not found."
        msg "Try to download and install from $ERLANG_RPM_URL..."
        wget $ERLANG_RPM_URL -P $SCRIPT_PATH/packages/erlang || return 1
    fi
    install_result=$(rpm -U $ERLANG_RPM_PATH 2>&1 | awk '{gsub(/^[ \t]+/,"");print}')
    if [ -z "$install_result" ]; then
        success "Installed $ERLANG_RPM_PATH"
    else
    	echo -e $install_result
    fi

    # install readline rpm
    if [ ! -f "$READLINE_RPM_PATH" ]; then
        msg "WARNING: $READLINE_RPM_PATH not found."
        msg "Try to download and install from $READLINE_RPM_URL..."
        wget $READLINE_RPM_URL -P $SCRIPT_PATH/packages/readline || return 1
    fi
    install_result=$(rpm -U $READLINE_RPM_PATH 2>&1 | awk '{gsub(/^[ \t]+/,"");print}')
    if [ -z "$install_result" ]; then
        success "Installed $READLINE_RPM_PATH"
    else
    	echo -e $install_result
    fi

    # install socat rpm
    if [ ! -f "$SOCAT_RPM_PATH" ]; then
        msg "WARNING: $SOCAT_RPM_PATH not found."
        msg "Try to download and install from $SOCAT_RPM_URL..."
        wget $SOCAT_RPM_URL -P $SCRIPT_PATH/packages/socat || return 1
    fi
    if uname -r | grep -q el7; then
        rpm --import "$SCRIPT_PATH/keys/RPM-GPG-KEY-LUX"
    fi
    install_result=$(rpm -U $SOCAT_RPM_PATH 2>&1 | awk '{gsub(/^[ \t]+/,"");print}')
    if [ -z "$install_result" ]; then
        success "Installed $SOCAT_RPM_PATH"
    else
        echo -e $install_result
    fi

    # import rabbitmq key
    if [ ! -f "$RABBITMQ_KEY_PATH" ]; then
        msg "WARNING: $RABBITMQ_KEY_PATH not found."
        msg "Try to download and import from $RABBITMQ_KEY_URL..."
        wget $RABBITMQ_KEY_URL -P $SCRIPT_PATH/keys || return 1
    fi
    rpm --import $RABBITMQ_KEY_PATH && success "Imported $RABBITMQ_KEY_PATH"

    # install rabbitmq rpm
    if [ ! -f "$RABBITMQ_RPM_PATH" ]; then
        msg "WARNING: $RABBITMQ_RPM_PATH not found."
        msg "Try to download and install from $RABBITMQ_RPM_URL..."
        wget $RABBITMQ_RPM_URL -P $SCRIPT_PATH/packages/rabbitmq || return 1
    fi
    install_result=$(rpm -U $RABBITMQ_RPM_PATH 2>&1 | awk '{gsub(/^[ \t]+/,"");print}')
    if [ -z "$install_result" ]; then
        success "Installed $RABBITMQ_RPM_PATH"
    else
    	echo -e $install_result
    fi
}

function set_rabbitmq_users() {
    if program_exists rabbitmqctl; then
        rabbitmqctl list_users | grep -q guest && \
            rabbitmqctl delete_user guest >/dev/null && \
            success "Deleted user [guest]"
        rabbitmqctl list_users | grep -q admin || {
            rabbitmqctl add_user admin $ADMIN_PWD >/dev/null && \
            rabbitmqctl set_user_tags admin administrator >/dev/null && \
            rabbitmqctl set_permissions -p / admin ".*" ".*" ".*" >/dev/null && \
            success "Added user [admin]"
        }
    else
        msg "Command not find: rabbitmqctl" && return 1
    fi
}

function set_rabbitmq_policies() {
    if program_exists rabbitmqctl; then
        rabbitmqctl list_policies | grep -q ha-all || {
            rabbitmqctl set_policy ha-all "^" '{"ha-mode":"all","ha-sync-mode":"automatic"}' >/dev/null && \
            success "Added policy [ha-all]"
        }
    else
        msg "Command not find: rabbitmqctl" && return 1
    fi
}

function install_rabbitmq() {
    rpm -q rabbitmq-server >/dev/null && \
        error "$(rpm -q rabbitmq-server) is already installed"
    update_rabbitmq_package || return 1

    curl -sL -o /usr/lib/rabbitmq/plugins/rabbitmq_delayed_message_exchange-${DELAYED_MESSAGE_VERSION}.ez  ${RABBITMQ_DELAYED_MESSAGE_PLUGIN}
    curl -sL -o /usr/lib/rabbitmq/plugins/rabbitmq_message_timestamp-${MESSAGE_TIMESTAMP_VERSION}.ez  ${RABBITMQ_MESSAGE_TIMESTAMP_PLUGIN}
    curl -sL -o /usr/lib/rabbitmq/plugins/rabbitmq_top-${TOP_VERSION}.ez  ${RABBITMQ_TOP_PLUGIN}
    curl -sL -o /tmp/autocluster-${AUTOCLUSTER_VERSION}.tgz  ${RABBITMQ_AUTOCLUSTER_PLUGIN}
    tar -xvz -C /usr/lib/rabbitmq -f /tmp/autocluster-${AUTOCLUSTER_VERSION}.tgz
    rm /tmp/autocluster-${AUTOCLUSTER_VERSION}.tgz

    # enable rabbitmq plugin
    rabbitmq-plugins enable autocluster \
        rabbitmq_delayed_message_exchange \
        rabbitmq_management \
        rabbitmq_management_visualiser \
        rabbitmq_consistent_hash_exchange \
        rabbitmq_federation \
        rabbitmq_federation_management \
        rabbitmq_message_timestamp \
#        rabbitmq_mqtt \
#        rabbitmq_recent_history_exchange \
#        rabbitmq_sharding \
#        rabbitmq_shovel \
#        rabbitmq_shovel_management \
#        rabbitmq_stomp \
#        rabbitmq_top \
#        rabbitmq_web_stomp \
          >/dev/null && \
        success "Enabled rabbitmq plugin [autocluster, rabbitmq_delayed_message_exchange, rabbitmq_management, rabbitmq_management_visualiser, rabbitmq_consistent_hash_exchange, rabbitmq_federation, rabbitmq_federation_management, rabbitmq_message_timestamp, rabbitmq_mqtt, rabbitmq_recent_history_exchange, rabbitmq_sharding, rabbitmq_shovel, rabbitmq_shovel_management, rabbitmq_stomp, rabbitmq_top, rabbitmq_web_stomp]" || return 1
    
    rabbitmq-plugins list

    # open firewall ports
    open_rabbitmq_ports && \
        success "Opened rabbitmq ports [$RABBITMQ_PORT/tcp,$RABBITMQ_HTTP_PORT/tcp,$ERL_EPMD_PORT/tcp,$RABBITMQ_DIST_PORT/tcp]" || \
        return 1

    # deploy rabbitmq.config
    RABBITMQ_CONFIG_PATH="$SCRIPT_PATH/config/$RABBITMQ_CONFIG_FILE"
    RABBITMQ_CONFIG_LOCATION=/etc/rabbitmq/rabbitmq.config
    cp $RABBITMQ_CONFIG_PATH $RABBITMQ_CONFIG_LOCATION && \
        success "Copyed $RABBITMQ_CONFIG_PATH to $RABBITMQ_CONFIG_LOCATION" || return 1

    # add host entry into /etc/hosts
    HOST_ENTRY=$(egrep "127.0.0.1 +$(hostname)" /etc/hosts)
    if [ "x$HOST_ENTRY" == "x" ]; then
        echo "127.0.0.1   $(hostname)" >> /etc/hosts && \
        success "Added [127.0.0.1   $(hostname)] into /etc/hosts" || return 1
    else
        msg "[$HOST_ENTRY] is already added into /etc/hosts"
    fi

    chmod 755 -R /etc/rabbitmq /usr/lib/rabbitmq  /var/lib/rabbitmq
    
    # set erlang cookie
    [ "x$COOKIE" == "x" ] && COOKIE="$ERLANG_COOKIE"
    ERLANG_COOKIE_PATH=/var/lib/rabbitmq/.erlang.cookie
    if [ ! -f "$ERLANG_COOKIE_PATH" ]; then
        msg "WARNING: $ERLANG_COOKIE_PATH is not exist, create new one"
        touch $ERLANG_COOKIE_PATH || return 1
    fi
    chmod 700 $ERLANG_COOKIE_PATH
    echo -n "$COOKIE" >$ERLANG_COOKIE_PATH
    chmod 400 $ERLANG_COOKIE_PATH
    chown rabbitmq:rabbitmq $ERLANG_COOKIE_PATH
    if [ $(cat $ERLANG_COOKIE_PATH) = "$COOKIE" ]; then
            success "Set erlang cookie value to $COOKIE"
    fi
}

function join_rabbitmq_cluster() {
    local ret=0
    
        if [ "x$privateDNS" != "x" ] && [ "$privateDNS" != $(hostname) ]; then
            if program_exists rabbitmqctl; then
                rabbitmqctl stop_app >/dev/null
                rabbitmqctl reset >/dev/null
                if [ "$NODE" == "ram" ]; then
                    rabbitmqctl join_cluster --ram rabbit@$privateDNS >/dev/null || let ret++
                else
                    rabbitmqctl join_cluster rabbit@$privateDNS >/dev/null || let ret++
                fi
                rabbitmqctl start_app >/dev/null
            else
                msg "Command not find: rabbitmqctl" && return 1
            fi
            if [ "$ret" -eq 0 ]; then
                success "Joined rabbit@$privateDNS"
                return 0
            else
                return 1
            fi
        fi
        
}

function restart_rabbitmq() {
    # kill all rabbitmq server processes
    local RABBITMQ_PIDS=$(ps -ef | grep ^rabbitmq | cut -c 9-16 | tr -s "\n" " ")
    if [ "x$RABBITMQ_PIDS" != "x" ]; then
        kill -9 $RABBITMQ_PIDS && success "Killed all rabbitmq server processes"
    fi
    # enable and start rabbitmq server
    chkconfig rabbitmq-server on
    service rabbitmq-server start
}

function print_usage() {
    echo "Usage: $(basename "$0") [OPTIONS...]"
    echo ""
    echo "Options"
    echo "  [-h|--help]                 Prints a short help text and exists"
    echo "  [-i|--install]              Install rabbitmq server"
    echo "  [-u|--update]               Update rabbitmq server"
    echo "  [-e|--erase]                Erase (uninstall) rabbitmq server"
    echo "  [-c|--cookie] <cookie>      Set erlang cookie"
    echo "  [-j|--join] <server>        Join rabbitmq cluster"
    echo "  [-n|--node] <disc|ram>      Set cluster node type"
}

# read the options
TEMP=`getopt -o hiuec:j:n: --long help,install,update,erase,cookie:,join:,node: -n $(basename "$0") -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true; do
    case "$1" in
        -h|--help) print_usage ; exit 0 ;;
        -i|--install) ACTION=install ; shift ;;
        -u|--update) ACTION=update ; shift ;;
        -e|--erase) ACTION=erase ; shift ;;
        -c|--cookie) COOKIE=$2 ; shift 2 ;;
        -j|--join) SERVER=$2 ; shift 2 ;;
        -n|--node) NODE=$2 ; shift 2 ;;
        --) shift ; break ;;
        *) error "Internal error!" ;;
    esac
done

# get script path
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# load settings
source "$SCRIPT_PATH/config/settings.conf" || exit 1

# set erlang and rabbitmq rpm & key path
case $(uname -r) in
    *el7*)
        ERLANG_RPM_PATH="$SCRIPT_PATH/package/erlang/${ERLANG_EL7_RPM_URL##*/}";
        ERLANG_RPM_URL="$ERLANG_EL7_RPM_URL";
        READLINE_RPM_PATH="$SCRIPT_PATH/package/readline/${READLINE_EL7_RPM_URL##*/}";
        READLINE_RPM_URL="$READLINE_EL7_RPM_URL";
        SOCAT_RPM_PATH="$SCRIPT_PATH/package/socat/${SOCAT_EL7_RPM_URL##*/}";
        SOCAT_RPM_URL="$SOCAT_EL7_RPM_URL" ;;
    *el6*|*amzn1*)
        ERLANG_RPM_PATH="$SCRIPT_PATH/package/erlang/${ERLANG_EL6_RPM_URL##*/}";
        ERLANG_RPM_URL="$ERLANG_EL6_RPM_URL";
        READLINE_RPM_PATH="$SCRIPT_PATH/package/readline/${READLINE_EL6_RPM_URL##*/}";
        READLINE_RPM_URL="$READLINE_EL6_RPM_URL";
        SOCAT_RPM_PATH="$SCRIPT_PATH/package/socat/${SOCAT_EL6_RPM_URL##*/}";
        SOCAT_RPM_URL="$SOCAT_EL6_RPM_URL" ;;
    *) error "Your system is not RHEL/CentOS" ;;
esac
RABBITMQ_RPM_PATH="$SCRIPT_PATH/package/rabbitmq/${RABBITMQ_RPM_URL##*/}"
RABBITMQ_KEY_PATH="$SCRIPT_PATH/keys/${RABBITMQ_KEY_URL##*/}"

if [ "x$ACTION" == "x" ] && [ "x$SERVER" == "x" ]; then
    error "$(basename "$0"): missing operand\n" \
    "Try '$(basename "$0") --help' for more information."
fi

echo "$NODE" | grep -qE "^disk$|^ram$|^$" || {
    error "$(basename "$0"): -n: must be disk or ram"
}

# if ACTION is erase, erase rabbitmq server
if [ "$ACTION" == "erase" ]; then
    erase_rabbitmq && {
        msg "\nThanks for erasing rabbitmq-server."
        msg "© `date +%Y`"
    } || error "Failed erase rabbitmq server"
    exit 0
fi

# if ACTION is update, update rabbitmq server
if [ "$ACTION" == "update" ]; then
    update_rabbitmq_package && restart_rabbitmq && {
        msg "\nThanks for updating rabbitmq-server."
        msg "© `date +%Y`"
    } || error "Failed update rabbitmq server"
    exit 0
fi

# if ACTION is install, install rabbitmq server
if [ "$ACTION" == "install" ]; then
    install_rabbitmq && restart_rabbitmq && set_rabbitmq_users && set_rabbitmq_policies && join_rabbitmq_cluster && {
        msg "\nThanks for installing rabbitmq-server."
        msg "© `date +%Y`"
    } || error "Failed install rabbitmq server"
else
    for privateDNS in ${SERVER//;/ } ; do 
        if [ "x$SERVER" != "x" ]; then
            join_rabbitmq_cluster && {
                msg "\nThanks for joining rabbitmq-server."
                msg "© `date +%Y`"
            } && break || error "Failed join rabbitmq server"
        fi
    done
fi
