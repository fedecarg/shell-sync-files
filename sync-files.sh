#!/bin/bash
################################################################################

       NAME_="sync-files"
    PURPOSE_="Sync files to remote servers"
   SYNOPSIS_=""
   REQUIRES_="Standard GNU commands"
        URL_="http://"
   CATEGORY_="file"
   PLATFORM_="Linux"
      SHELL_="bash"
    VERSION_="2.0"
     AUTHOR_="Federico Cargnelutti"

################################################################################

# Script directory
SCRIPT_DIR=$(dirname $0)

# Working directory
WORKING_DIR="$(pwd)/deploy"

# Function =====================================================================
# Name:        usage
# Description: Display usage information for this script.
# Parameter:   none
#===============================================================================
function usage()
{
    echo "
NAME:
    $NAME_ 
VERSION:
    $VERSION_
DESCRIPTION:
    $PURPOSE_
USAGE: 
    ${NAME_} [-c] -e <environment>
REQUIRES: 
    $REQUIRES_
OPTIONS:
    -e  Environment: dev, stg or prd
    -c  Cron job (suppress confirmation messages) - optional
    -h  Usage information
"
    exit 1
}

# Function =====================================================================
# Name:        trigger_error
# Description: Generates a user-level error, warning or notice message
# Parameter:   $1 <error message>, $2 ["error","notice","warning"]
#===============================================================================
function trigger_error()
{
	if [ $# -eq 1 ] || [ "$2" == "error" ]; then
		echo "error: $1"
		exit 1
	else
		echo "trigger_error(): invalid arguments"
		exit 1
	fi
}

# Function =====================================================================
# Name:        install_ssh_key
# Description: Generate authentication key for ssh
# Parameter:   $1 <sync.hosts file>
#===============================================================================
function install_ssh_key()
{
    HOST_FILE="${1}"
    if [ ! -f $HOST_FILE ]; then
        trigger_error "no such file: ${HOST_FILE}"
    fi
    
    if [ ! -d ${HOME}/.ssh ]; then 
        mkdir -p ${HOME}/.ssh
    fi
    
    if [ ! -f ${HOME}/.ssh/id_dsa.pub ]; then
        echo "[${NAME_}] Local SSH key does not exist. Creating ..."
        echo "[${NAME_}] JUST PRESS ENTER WHEN ssh-keygen ASKS FOR A PASSPHRASE!"
        echo ""
        ssh-keygen -t dsa -f ${HOME}/.ssh/id_dsa
        if [ $? -gt 0 ]; then
            trigger_error "ssh-keygen returned errors"
        fi
    fi
    
    if [ ! -f ${HOME}/.ssh/id_dsa.pub ]; then
        trigger_error "unable to create a local SSH key"
    fi
    
    while read REMOTE_HOST; do
        echo "[${NAME_}] Local SSH key present, installing remotely ..."
        REMOTE_USER=${HOST%@*}        
        cat $HOME/.ssh/id_dsa.pub | ssh ${REMOTE_HOST} "if [ ! -d ~${REMOTE_USER}/.ssh ];then mkdir -p ~${REMOTE_USER}/.ssh ; fi && if [ ! -f ~${REMOTE_USER}/.ssh/authorized_keys2 ];then touch ~${REMOTE_USER}/.ssh/authorized_keys2 ; fi &&  sh -c 'cat - >> ~${REMOTE_USER}/.ssh/authorized_keys2 && chmod 600 ~${REMOTE_USER}/.ssh/authorized_keys2'"
        if [ $? -gt 0 ]; then
            trigger_error "ssh returned errors"
        else 
            echo "[${NAME_}] Added key to $REMOTE_HOST"
        fi
    done < $HOST_FILE
}

#
# Get options
#
while getopts e:khc OPTION; do
    case "$OPTION" in
       e) environment="$OPTARG";;
       c) is_cron=1;;
       k) auth_key=1;;
       h) usage;;
       \?) usage;;
    esac
done
shift $(( $OPTIND - 1 ))

#
# Check options
#
if [ ! -d $WORKING_DIR ]; then
    trigger_error "invalid root directory: $(pwd)"
elif [ ! "${environment}" ]; then
    usage
fi

#
# Define env directory
#
if [ -d "${WORKING_DIR}/env/${environment}" ]; then
    ENV_DIR="${WORKING_DIR}/env/${environment}"
elif [ -d "${SCRIPT_DIR}/env/${environment}" ]; then
    ENV_DIR="${SCRIPT_DIR}/env/${environment}"
else 
    trigger_error "no such environment: ${environment}"
fi

#
# Define sync.hosts file
#
if [ -f "${WORKING_DIR}/env/${environment}/sync.hosts" ]; then
    HOST_FILE="${WORKING_DIR}/env/${environment}/sync.hosts"
    echo "[${NAME_}] Use ${HOST_FILE} ..."
elif [ -f "${SCRIPT_DIR}/env/${environment}/sync.hosts" ]; then
    HOST_FILE="${SCRIPT_DIR}/env/${environment}"
else 
    trigger_error "no such file: ${ENV_DIR}/sync.hosts"
fi

#
# Define sync.exlude file
#
if [ -f "${WORKING_DIR}/env/${environment}/sync.exclude" ]; then
    EXCLUDE_FILE="${WORKING_DIR}/env/${environment}/sync.exclude"
    echo "[${NAME_}] Use ${EXCLUDE_FILE} ..."
elif [ -f "${SCRIPT_DIR}/env/${environment}/sync.exclude" ]; then
    EXCLUDE_FILE="${SCRIPT_DIR}/env/${environment}/sync.exclude"
fi

#
# Define sync.path file
#
if [ -f "${WORKING_DIR}/env/${environment}/sync.path" ]; then
    PATH_FILE="${WORKING_DIR}/env/${environment}/sync.path"
    echo "[${NAME_}] Use ${PATH_FILE} ..."
elif [ -f "${SCRIPT_DIR}/env/${environment}/sync.path" ]; then
    PATH_FILE="${SCRIPT_DIR}/env/${environment}"
else 
    trigger_error "no such file: ${ENV_DIR}/sync.path"
fi

source $PATH_FILE
if [ ! -d "$SOURCE_DIR" ] && [ ! -f "$SOURCE_DIR" ]; then
    trigger_error "invalid source directory: ${SOURCE_DIR}"
elif [ ! "$TARGET_DIR" ]; then
    trigger_error "invalid target directory: ${TARGET_DIR}"
fi

#
# Check ssh key
#
if [ "${auth_key}" ]; then
    echo -n "[${NAME_}] Generate authentication key for ssh [n/Y]? " 
    read confirm_action
    if [ "$confirm_action" == "Y" ]; then 
        install_ssh_key $HOST_FILE
    fi
fi

#
# Define log directory
#
LOG_DIR="${SCRIPT_DIR}/log"
if [ -d "${WORKING_DIR}/log" ]; then
    LOG_DIR="${WORKING_DIR}/log"
fi

#
# Define rsync options
#
rsync_opt="-razv --delete --force"
if [ "${EXCLUDE_FILE}" ]; then
    rsync_opt="${rsync_opt} --exclude-from=${EXCLUDE_FILE}"
fi

rsync_id=$(date '+%d%m%y-%H%M%S')
timestamp=$(date '+%d-%m-%Y %H:%M:%S')

#
# Display confirmation message
#
if [ ! "${is_cron}" ]; then
    echo "[${NAME_}]"
    echo "[${NAME_}] Directory"
    echo "[${NAME_}]     - Source: ${SOURCE_DIR}"
    echo "[${NAME_}]     - Target: ${TARGET_DIR}"
    echo "[${NAME_}] Exclude"
    while read PATTERN; do
        echo "[${NAME_}]     - ${PATTERN}"
    done < $EXCLUDE_FILE
    echo "[${NAME_}] Hosts"
    while read HOST; do
        echo "[${NAME_}]     - ${HOST}"
    done < $HOST_FILE
    echo "[${NAME_}]"
    echo -n "[${NAME_}] Transfer files to remote host(s) [n/Y]? " 
    read confirm_action
    [[ "$confirm_action" != "Y" ]] && { echo "exit: no files were transferred"; exit 1; }
fi

#
# Define pre-hook commands
#
prehook_file="${WORKING_DIR}/env/${environment}/sync.prehook"
if [ -f $prehook_file ]; then
    prehook_cmds=$(sed -e :a -e '$!N;s/\n/; /;ta' $prehook_file | sed -e 's/"/'\''/g')
fi

#
# Transfer files
#
while read HOST; do
    echo "[${NAME_}] Copying files to ${HOST}... "
    filename="${environment}.${rsync_id}.${HOST#*@}"
    if [ "${prehook_cmds}" ]; then
        ssh $HOST "${prehook_cmds}"
        if [ $? -gt 0 ]; then
            trigger_error "ssh failed to execute: ${prehook_cmds}"
        fi
    fi
    rsync $rsync_opt $SOURCE_DIR $HOST:$TARGET_DIR | tee ${LOG_DIR}/${filename}.log
    if [ $? -gt 0 ]; then
        trigger_error "rsync failed to copy files to ${HOST}"
    fi
done < $HOST_FILE

exit 0
