#!/bin/bash
#
# Copyright (C) 2007-2008 Federico Cargnelutti.
# $Id$
##############################################################################

       NAME_="sync-files.sh"
    PURPOSE_="Sync files to the production or staging server"
   SYNOPSIS_="$NAME_ [-r] [-p] [project name]"
   REQUIRES_="Standard GNU commands"
        URL_="http://"
   CATEGORY_="file"
   PLATFORM_="Linux"
      SHELL_="bash"
    VERSION_="1.0"
     AUTHOR_="Federico Cargnelutti <fedecarg@gmail.com>"

##############################################################################
#
# The document root directory under which the 
# current script is executing
#
DOCUMENT_ROOT=$(dirname $0)

#
# Include global config file
#
source "${DOCUMENT_ROOT}/conf/sync-files.properties"

#
# Include functions file
#
source "${DOCUMENT_ROOT}/library/functions.inc.sh"

#
# Check args
#
[[ $# -eq 0 ]] && { trigger_error "missing argument, type ${NAME_} -u for usage information"; }

#
# Get options
#
while getopts luotp: OPTION; do
    case "$OPTION" in
		p) project_file="$OPTARG";;
		l) list_only=1;;
		o) remote_conn=1;;
		u) usage;;
		\?) trigger_error "type ${NAME_} -u for usage information";;
    esac
done
shift $(( $OPTIND - 1 ))

#
# Args check 
#
[[ ! "$project_file" ]] && { trigger_error "project name missing [-p] [project name]"; }

#
# Load properties file
#	
config_file="${DOCUMENT_ROOT}/projects/${project_file}/sync.properties"
if [ ! -r "$config_file" ]; then
	trigger_error "check that the file ${config_file} exists and that you have permission to read it"
else
	source $config_file
	if [ ! "$PROJECT_NAME" ]; then
		trigger_error "PROJECT_NAME missing"
	elif [ ! "$DESTINATION_DIR" ]; then
		trigger_error "invalid destination directory: ${DESTINATION_DIR}"
	elif [ ! -d "$SOURCE_DIR" ]; then
		trigger_error "invalid source directory: ${SOURCE_DIR}" 
	fi
fi

#
# Overwrite config values
#
if [ "$remote_conn" ]; then
	# Set REMOTE_HOST
	echo -n "Remote host (${REMOTE_HOST}): "
	read REMOTE_HOST
	if [ ! "$REMOTE_HOST" ]; then
		trigger_error "remote host not defined."
	fi
	# Set SYNC_USER
	echo -n "Remote user (${SYNC_USER}): "
	read SYNC_USER
	if [ ! "$SYNC_USER" ]; then
		trigger_error "remote user not defined."
	fi
fi

#
# Display information
#
echo
echo "Project information"
echo "----------------------------------------"
echo "Name:          $PROJECT_NAME"
echo "File:          $config_file"
echo
echo "Sync files to ${SYNC_TYPE} server"
echo "----------------------------------------"
echo "Source:        $SOURCE_DIR"
echo "Destination:   ${SYNC_USER}@${REMOTE_HOST}:${DESTINATION_DIR}"

exclude_file="${DOCUMENT_ROOT}/projects/${project_file}/sync.exclude"
if [ ! -r $exclude_file ]; then
	EXCLUDE_ARG=""
else 
	EXCLUDE_ARG="--exclude-from=$exclude_file"
	echo
	echo "Excluded patterns"
	echo "----------------------------------------"
	cat $exclude_file
fi

echo 
if [ "$list_only" ]; then
	exit 0
fi

echo -n "Copy files to ${SYNC_TYPE} server [n/Y]? "

#
# Request confirmation
#
read confirm_sync
[[ "$confirm_sync" != "Y" ]] && { trigger_error "no files were transferred" "notice"; exit 1; }
 
#
# Check log file 
#
[[ ! -r "${DOCUMENT_ROOT}/log/sync-files.log" ]] && { touch ${DOCUMENT_ROOT}/log/sync-files.log; }

#
# Include sync file
#
source "${DOCUMENT_ROOT}/library/sync.inc.sh"
rsync_files

exit 0
