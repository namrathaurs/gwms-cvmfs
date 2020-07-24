#!/bin/bash

# Project:
#       GlideinWMS
#
# 
# Description:
#       This script checks the status of CVMFS mounted on the filesystem in the worker node. 
#	If CVMFS is mounted, the script unmounts all CVMFS repositories using the umountrepo utility and 
#	prints appropriate message. If CVMFS is not found to be mounted, then an appropriate message
#	will be displayed.
#
# Dependencies:
#	cvmfs_helper_funcs.sh
#
# Author:
#       Namratha Urs
#
# Version:
#       1.0
#



# name of the glidein configuration file and entry id
glidein_config=$1
entry_id=$2

# to implement custom logging
# https://stackoverflow.com/questions/42403558/how-do-i-manage-log-verbosity-inside-a-shell-script
# WORKAROUND: redirect stdout and stderr to some file 
#LOGFILE="cvmfs_all.log"
#exec &> $LOGFILE


# source the script containing helper functions before executing this script
source cvmfs_helper_funcs.sh

########################################################################################################
# This is the start of the main program.
########################################################################################################

log_marker "START" "UNMOUNTING"

df -h | grep /cvmfs &> /dev/null
IS_CVMFS_MOUNT=$?

if [[ $IS_CVMFS_MOUNT -eq 0 ]]; then
	echo "Unmounting CVMFS..."	
	cvmfsexec/umountrepo -a
	echo -e "CVMFS repositories unmounted\n"

	# see if the repositories were successfully unmounted
	df -h

else
	echo "CVMFS repositories are not mounted"
	
fi

log_marker "END" "UNMOUNTING"

########################################################################################################
# This is the end of the main program.
########################################################################################################
