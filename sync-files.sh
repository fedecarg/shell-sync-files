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
     AUTHOR_="Federico Cargnelutti <fedecarg@gmail.com>"

################################################################################

# Script directory
SCRIPT_DIR=$(dirname $0)

# Working directory
WORKING_DIR="$(pwd)/deploy"

# Unique ID
RSYNC_ID=$(date '+%d%m%y-%H%M%S')

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
    ${NAME_} -e <environment> create-dir
    ${NAME_} -e <environment> create-ssh-key
    ${NAME_} [-q] -e <environment>
REQUIRES: 
    $REQUIRES_
OPTIONS:
    -e  Environment: dev, stg or prd
    -q  Suppress confirmation messages - optional
    -h  Usage information
KEYWORDS
    create-dir       Generate skeleton directory
    create-ssh-key   Generate SSH key
"
    exit 0
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
# Name:        create_ssh_key
# Description: Generate authentication key for ssh
# Parameter:   $1 <HOST_FILE>
#===============================================================================
function create_ssh_key()
{
    echo -n "[${NAME_}] Generate authentication key for ssh [n/Y]? " 
    read confirm_action
    if [ "$confirm_action" != "Y" ]; then 
         echo "exit: no keys where generated"
         exit 1
    fi
        
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
    
    exit 0
}

# Function =====================================================================
# Name:        create_dir
# Description: Create directory structure
# Parameter:   $1 <environment>
#===============================================================================
function create_dir()
{
    if [ -d "${WORKING_DIR}/env/${1}" ]; then
        trigger_error "directory already exists: ${1}"
    fi
    
    echo -n "[${NAME_}] Source directory: " 
    read SOURCE_DIR
    echo -n "[${NAME_}] Target directory: " 
    read TARGET_DIR
    echo -n "[${NAME_}] User name and hostname (username@hostname): "
    read HOST
    echo -n "[${NAME_}] Create sync.exclude file [Y/n]? "
    read create_exclude_file
    
    echo "[${NAME_}] Creating directory structure: ${WORKING_DIR}"
    mkdir -p ${WORKING_DIR}/{env/${1},log}
    env_path="${WORKING_DIR}/env/${1}"
    
    echo "[${NAME_}] Creating files ..."
    
    if [ "${create_exclude_file}" == "Y" ]; then
        touch ${env_path}/sync.exclude
        echo -e ".DS_Store\n.svn\n*~\n_*" >> ${env_path}/sync.exclude
    fi
    if [ "${HOST}" != "" ]; then
        touch ${env_path}/sync.host
        echo $HOST >> ${env_path}/sync.host
    fi    
    
    touch ${env_path}/sync.dir    
    echo -e "SOURCE_DIR=\"${SOURCE_DIR}\"\nTARGET_DIR=\"${TARGET_DIR}\"" >> ${env_path}/sync.dir
    
    echo "[${NAME_}] Done"
    exit 0
}    
    
#
# Get options
#
while getopts e:qh OPTION; do
    case "$OPTION" in
       e) environment="$OPTARG";;
       q) quiet=1;;
       h) usage;;
       \?) usage;;
    esac
done
shift $(( $OPTIND - 1 ))

#
# Check options
#
if [ ! "${environment}" ]; then
    usage
elif [ "${1}" == "create-dir" ]; then
    create_dir $environment
elif [ ! -d $WORKING_DIR ]; then
    trigger_error "directory missing: $(pwd)/deploy"
fi

#
# Define LOG_DIR (log directory)
#
LOG_DIR="${SCRIPT_DIR}/log"
if [ -d "${WORKING_DIR}/log" ]; then
    LOG_DIR="${WORKING_DIR}/log"
fi

#
# Define HOST_FILE (sync.host file)
#
if [ -f "${WORKING_DIR}/env/${environment}/sync.host" ]; then
    HOST_FILE="${WORKING_DIR}/env/${environment}/sync.host"
    echo "[${NAME_}] Using ${HOST_FILE}"
elif [ -f "${SCRIPT_DIR}/env/${environment}/sync.host" ]; then
    HOST_FILE="${SCRIPT_DIR}/env/${environment}/sync.host"
else 
    trigger_error "no such file: ${WORKING_DIR}/env/${environment}/sync.host"
fi
if [ "${1}" == "create-ssh-key" ]; then
    create_ssh_key $HOST_FILE
fi

#
# Define EXCLUDE_FILE (sync.exlude file)
#
if [ -f "${WORKING_DIR}/env/${environment}/sync.exclude" ]; then
    EXCLUDE_FILE="${WORKING_DIR}/env/${environment}/sync.exclude"
    echo "[${NAME_}] Using ${EXCLUDE_FILE}"
elif [ -f "${SCRIPT_DIR}/env/${environment}/sync.exclude" ]; then
    EXCLUDE_FILE="${SCRIPT_DIR}/env/${environment}/sync.exclude"
fi

#
# Define DIR_FILE (sync.dir file)
#
if [ -f "${WORKING_DIR}/env/${environment}/sync.dir" ]; then
    DIR_FILE="${WORKING_DIR}/env/${environment}/sync.dir"
    echo "[${NAME_}] Using ${DIR_FILE}"
else 
    trigger_error "no such file: ${ENV_DIR}/sync.dir"
fi

#
# Define prehook and posthook commands
#
prehook_file="${WORKING_DIR}/env/${environment}/sync.prehook"
if [ -f $prehook_file ]; then
    prehook_cmds=$(sed -e :a -e '$!N;s/\n/; /;ta' $prehook_file | sed -e 's/"/'\''/g')
fi
posthook_file="${WORKING_DIR}/env/${environment}/sync.posthook"
if [ -f $posthook_file ]; then
    posthook_cmds=$(sed -e :a -e '$!N;s/\n/; /;ta' $posthook_file | sed -e 's/"/'\''/g')
fi

source $DIR_FILE
if [ ! -d "$SOURCE_DIR" ] && [ ! -f "$SOURCE_DIR" ]; then
    trigger_error "invalid source directory"
elif [ ! "$TARGET_DIR" ]; then
    trigger_error "invalid target directory"
fi

#
# rsync options
#
rsync_opt="-razv --delete --force"
if [ "${EXCLUDE_FILE}" ]; then
    rsync_opt="${rsync_opt} --exclude-from=${EXCLUDE_FILE}"
fi

#
# Display confirmation message
#
if [ ! "${quiet}" ]; then
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
# Transfer files
#
while read HOST; do
    echo "[${NAME_}] Copying files to ${HOST}... "
    filename="${environment}.${RSYNC_ID}.${HOST#*@}"
    if [ "${prehook_cmds}" ]; then
        ssh $HOST "${prehook_cmds}"
        if [ $? -gt 0 ]; then
            trigger_error "ssh failed to execute prehook commands"
        fi
    fi
    
    rsync $rsync_opt $SOURCE_DIR $HOST:$TARGET_DIR | tee ${LOG_DIR}/${filename}.log
    
    if [ $? -gt 0 ]; then
        trigger_error "rsync failed to copy files to ${HOST}"
    fi
    if [ "${posthook_cmds}" ]; then
        ssh $HOST "${posthook_cmds}"
        if [ $? -gt 0 ]; then
            trigger_error "ssh failed to execute posthook commands"
        fi
    fi
done < $HOST_FILE

exit 0
