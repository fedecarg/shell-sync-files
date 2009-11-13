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

# Build directory
BUILD_DIR="$(pwd)/build"

# Build unique ID
BUILD_NUMBER=$(date '+%d%m%y-%H%M%S')

# Build date
BUILD_DATE=$(date '+%Y%m%d')


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
    ${NAME_} -e <environment> package
    ${NAME_} [-q] -e <environment> deploy
REQUIRES: 
    $REQUIRES_
OPTIONS:
    -e  Environment: dev, stg or prd
    -q  Suppress confirmation messages - optional
    -h  Usage information
KEYWORDS
    create-dir       Create project directory
    create-ssh-key   Create SSH key on remote host(s)
    package          Create RPM file
    deploy           Transfer file(s) and execute pre and post commands
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
# Parameter:   none
#===============================================================================
function create_ssh_key()
{
    echo -n "[${NAME_}] Generate authentication key for ssh [n/Y]? " 
    read confirm_action
    if [ "$confirm_action" != "Y" ]; then 
         echo "exit: no keys where generated"
         exit 1
    fi
    
    if [ ! -f "${HOST_FILE}" ]; then
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
# Parameter:   $1 <ENVIRONMENT>
#===============================================================================
function create_dir()
{
    if [ "${ENVIRONMENT}" == "" ]; then
        trigger_error "environment parameter missing"
    elif [ -d "${WORKING_DIR}/env/${1}" ]; then
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

# Function =====================================================================
# Name:        package
# Description: Package files
# Parameter:   none
#===============================================================================
function package()
{
    if [ -f "${ENV_DIR}/package" ]; then
        trigger_error "package file missing: ${ENV_DIR}/package"
    fi
    source ${ENV_DIR}/package
    exit 0
}

# Function =====================================================================
# Name:        deploy
# Description: Transfer files using rsync and execute pre and post commands 
# Parameter:   none
#===============================================================================
function deploy()
{
    # Define EXCLUDE_FILE (sync.exlude file)
    if [ -f "${ENV_DIR}/sync.exclude" ]; then
        EXCLUDE_FILE="${ENV_DIR}/sync.exclude"
        echo "[${NAME_}] Using ${EXCLUDE_FILE}"
    elif [ -f "${SCRIPT_DIR}/env/${ENVIRONMENT}/sync.exclude" ]; then
        EXCLUDE_FILE="${SCRIPT_DIR}/env/${ENVIRONMENT}/sync.exclude"
    fi
    
    # Define DIR_FILE (sync.dir file)
    if [ -f "${ENV_DIR}/sync.dir" ]; then
        DIR_FILE="${ENV_DIR}/sync.dir"
        echo "[${NAME_}] Using ${DIR_FILE}"
    else 
        trigger_error "no such file: ${ENV_DIR}/sync.dir"
    fi
    
    # Define prehook and posthook commands
    prehook_file="${ENV_DIR}/sync.prehook"
    if [ -f $prehook_file ]; then
        prehook_cmds=$(sed -e :a -e '$!N;s/\n/; /;ta' $prehook_file | sed -e 's/"/'\''/g')
    fi
    posthook_file="${ENV_DIR}/sync.posthook"
    if [ -f $posthook_file ]; then
        posthook_cmds=$(sed -e :a -e '$!N;s/\n/; /;ta' $posthook_file | sed -e 's/"/'\''/g')
    fi
    
    source $DIR_FILE
    if [ ! -d "$SOURCE_DIR" ] && [ ! -f "$SOURCE_DIR" ]; then
        trigger_error "invalid source directory"
    elif [ ! "$TARGET_DIR" ]; then
        trigger_error "invalid target directory"
    fi
    
    # rsync options
    rsync_opt="-razv --delete --force"
    if [ "${EXCLUDE_FILE}" ]; then
        rsync_opt="${rsync_opt} --exclude-from=${EXCLUDE_FILE}"
    fi
    
    # Display confirmation message
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
    
    # Transfer files
    while read HOST; do
        echo "[${NAME_}] Copying files to ${HOST}... "
        filename="${ENVIRONMENT}.${BUILD_NUMBER}.${HOST#*@}"
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
}

# Main =========================================================================

#
# Get options
#
while getopts e:qh OPTION; do
    case "$OPTION" in
       e) ENVIRONMENT="$OPTARG";;
       q) quiet=1;;
       h) usage;;
       \?) usage;;
    esac
done
shift $(( $OPTIND - 1 ))

#
# Validate options
#
if [ ! "${1}" ] || [ ! "${ENVIRONMENT}" ]; then
    usage
elif [ "${1}" == "create-dir" ]; then
    create_dir $ENVIRONMENT
elif [ ! -d $WORKING_DIR ]; then
    trigger_error "directory missing or invalid: ${WORKING_DIR}"
fi

#
# Define LOG_DIR (log directory)
#
LOG_DIR="${SCRIPT_DIR}/log"
if [ -d "${WORKING_DIR}/log" ]; then
    LOG_DIR="${WORKING_DIR}/log"
fi

#
# Define ENV_DIR (environment directory)
#
ENV_DIR=${WORKING_DIR}/env/${ENVIRONMENT}

#
# Define HOST_FILE (sync.host file)
#
if [ -f "${ENV_DIR}/sync.host" ]; then
    HOST_FILE="${ENV_DIR}/sync.host"
    echo "[${NAME_}] Using ${HOST_FILE}"
elif [ -f "${SCRIPT_DIR}/env/${ENVIRONMENT}/sync.host" ]; then
    HOST_FILE="${SCRIPT_DIR}/env/${ENVIRONMENT}/sync.host"
else 
    trigger_error "no such file: ${ENV_DIR}/sync.host"
fi

if [ "${1}" == "create-ssh-key" ]; then
    create_ssh_key
elif [ "${1}" == "package" ]; then
    package
elif [ "${1}" == "deploy" ]; then
    deploy
else
    usage
fi

