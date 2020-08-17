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


########################################################################################################
# Start: main program
########################################################################################################

loginfo "..."
loginfo  "Start log for unmounting CVMFS"

# check if CVMFS has been mounted on the worker node
df -h | grep /cvmfs &> /dev/null

if [[ $? -eq 0 ]]; then
	# CVMFS mount points exist in the filesystem
	loginfo "Unmounting CVMFS..."
	$cvmfs_utils_dir/.cvmfsexec/umountrepo -a
	
	# check again to ensure all CVMFS repositories were unmounted by umountrepo
	df -h | grep /cvmfs &> /dev/null && logerror "One or more CVMFS repositories might not be completely unmounted" || loginfo "CVMFS repositories unmounted"
	
	# returning 0 to indicate the unmount process was successful
	true	

else
	# CVMFS mount points do not exist in the file system
	loginfo "No CVMFS repositories found mounted. Exiting the script..."
	
	# returning 1 to indicate that unmount process failed (i.e. nothing was unmounted as CVMFS was not previously mounted)
	false
	
fi

########################################################################################################
# End: main program
########################################################################################################
