# functions.inc.sh
# $Id$

# Function ==================================================================
# Name:        usage
# Description: Display usage information for this script.
# Parameter:   none
#===========================================================================
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
    $SYNOPSIS_
REQUIRES: 
    $REQUIRES_
OPTIONS:
    -p  Project name. E.g.: site.com
    -o  Overwrite remote connection details
    -u  Usage information
"
    exit 1
}

# Function ==================================================================
# Name:        trigger_error
# Description: Generates a user-level error, warning or notice message
# Parameter:   $1 <error message>, $2 ["error","notice","warning"]
#===========================================================================
function trigger_error()
{
	if [ $# -eq 1 ] || [ "$2" == "error" ]; then
		echo "${NAME_}: error: $1"
		exit 1
	elif [ $# -eq 2 ]; then
		echo "${NAME_}: $2: $1"
		return 1
	else
		echo "${NAME_}: trigger_error(): invalid arguments"
		exit 1
	fi
}

# Function ==================================================================
# Name:        is_root
# Description: Checks if the user is root
# Parameter:   none
#===========================================================================
function is_root()
{
	local ROOT_UID=0
	if [ "$UID" != "$ROOT_UID" ]; then
		return 1
	else
		return 0
	fi  
} 
