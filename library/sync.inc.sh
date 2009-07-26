# sync.inc.sh
# $Id$

# Function ==================================================================
# Name:        rsync_files
# Description: Executes the rsync command
# Parameter:   none
#===========================================================================
function rsync_files() 
{
	local params=$EXCLUDE_ARG $SOURCE_DIR $REMOTE_USER@$REMOTE_HOST:$DESTINATION_DIR
	
	if [ "$list_only" == 1 ]; then
		$params="--list-only ${params}"
	fi
	
	rsync -e ssh -razv $params
	return $? 
}
