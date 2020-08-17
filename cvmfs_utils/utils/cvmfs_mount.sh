#!/bin/bash
# Project:
#	GlideinWMS
#
# 
# Description:
#	This script performs system checks on the worker node to collect system information and detects if 
#	CVMFS has been already installed/mounted. If CVMFS does not exist, the script further determines
#	the reliable option to mount CVMFS repositories on the worker node filesystem and mounts the 
#	corresponding repositories to make CVMFS available on the worker node.
#
#
# Dependencies:
#	cvmfs_helper_funcs.sh
#
# Author:
#	Namratha Urs
#
# Version:
#	1.0
#

########################################################################################################
# Start: main program
########################################################################################################

# reset all variables used in this script's namespace before executing the rest of the script
variables_reset

# perform checks on the worker node that will be used to assess whether CVMFS can be mounted or not
perform_system_check

#loginfo "Start log for mounting CVMFS"

# print/display all information pertaining to system checks performed previously (facilitates easy troubleshooting)
log_all_system_info

# initializing CVMFS repositories to a variable for easy addition/removal in the future
GLIDEIN_CVMFS_CONFIG_REPO=cvmfs-config.cern.ch
GLIDEIN_CVMFS_REPOS=config-osg.opensciencegrid.org:singularity.opensciencegrid.org:cms.cern.ch
# (optional) set an environment variable that suggests additional repos to be mounted after config repos are mounted

# detect if CVMFS is mounted (using the global variable created during perform_system_check)
if [ $GWMS_IS_CVMFS_MNT -eq 0 ]; then
	# do nothing (if CVMFS is available)
	loginfo "CVMFS is mounted on the worker node and available for use"
	# exit 0
else
	# if not, install CVMFS via mountrepo or cvmfsexec
	loginfo "CVMFS is NOT mounted on the worker node! Installing now..."
	# check the operating system distribution
	#if [[ $GWMS_OS_DISTRO = RHEL ]]; then
	# evaluate the worker node's system configurations to decide whether CVMFS can be mounted or not
	loginfo "Evaluating the worker node..."
	# display operating system information
	print_os_info

	# assess the worker node based on its existing system configurations and perform next steps accordingly
	if evaluate_worker_node_config ; then
		# if evaluation was true, then proceed to mount CVMFS
		loginfo "Mounting CVMFS repositories..."
		mount_cvmfs_repos $GLIDEIN_CVMFS_CONFIG_REPO $GLIDEIN_CVMFS_REPOS
	else
		# if evaluation was false, then exit from this activity of mounting CVMFS
		exit 1
	fi	
	#else
	# if operating system distribution is non-RHEL (any non-rhel OS)
	# display operating system information and a user-friendly message	
	#print_os_info
	#logwarn "This is a non-RHEL OS and is not covered in the implementation yet!"
	# ----- Further Implementation: TBD (To Be Done) ----- #
	#fi

fi

#loginfo "End log for mounting CVMFS"

########################################################################################################
# End: main program
#######################################################################################################
