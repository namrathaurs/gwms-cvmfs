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



# name of the glidein configuration file and entry id
glidein_config=$1
entry_id=$2

# to implement custom logging
# https://stackoverflow.com/questions/42403558/how-do-i-manage-log-verbosity-inside-a-shell-script
# WORKAROUND: redirect stdout and stderr to some file 
#LOGFILE="cvmfs_all.log"
#exec &> $LOGFILE

# source the script containing helper functions before executing this script
#source cvmfs_helper_funcs.sh

########################################################################################################
# This is the start of the main program...
########################################################################################################
variables_reset

perform_system_check

#loginfo "Start log for mounting CVMFS"

log_all_system_info

# initializing the repos for CVMFS
GLIDEIN_CVMFS_CONFIG_REPO=cvmfs-config.cern.ch
GLIDEIN_CVMFS_REPOS=config-osg.opensciencegrid.org:singularity.opensciencegrid.org:cms.cern.ch
# set an environment variable that suggests additional repos to be mounted after config repos are mounted
#export CVMFS_REPOS=$REPOS

# detect if CVMFS is installed (using the global variable)
if [ $GWMS_IS_CVMFS_MNT -eq 0 ]; then
	# do nothing (if CVMFS is installed)
	loginfo "CVMFS is installed on the worker node and available for use"
	#exit 0
else
	# if not, install CVMFS via mountrepo or cvmfsexec
	loginfo "CVMFS is NOT installed on the worker node! Installing now..."
	# check the operating system distro
	if [[ $GWMS_OS_DISTRO = RHEL ]]; then
		# evaluate the worker node's system configurations to decide whether CVMFS can be mounted or not
		loginfo "Evaluating the worker node..."
		print_os_info
		
		evaluate_worker_node_config		
		# depending on the previously caught exit status, perform next steps accordingly
		if [[ $? -eq 0 ]]; then
			loginfo "Mounting CVMFS repositories..."
			mount_cvmfs_repos $GLIDEIN_CVMFS_CONFIG_REPO $GLIDEIN_CVMFS_REPOS
			#loginfo "CVMFS repositories mounted"
		else
			exit 1
		fi	
	else	# GWMS_OS_DISTRO = "non-rhel" (any non-rhel OS)
		print_os_info
		logwarn "This is a non-RHEL OS and is not covered in the implementation yet!"
		# ----- THINK ABOUT THIS FURTHER ----- #
	fi

fi

#loginfo "End log for mounting CVMFS"

########################################################################################################
# This is the end of the main program.
#######################################################################################################

