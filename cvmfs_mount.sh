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
source cvmfs_helper_funcs.sh

########################################################################################################
# This is the start of the main program...
########################################################################################################

perform_system_check

log_marker "START" "MOUNTING"

log_system_info

# initializing the repos for CVMFS
CVMFS_CONFIG_REPO=cvmfs-config.cern.ch
CVMFS_REPOS=config-osg.opensciencegrid.org:singularity.opensciencegrid.org:cms.cern.ch
# set an environment variable that suggests additional repos to be mounted after config repos are mounted
#export CVMFS_REPOS=$REPOS

# detect if CVMFS is installed (using the global variable)
if [ $IS_CVMFS_MNT -eq 0 ]; then
	# do nothing (if CVMFS is installed)
	echo -e "\nCVMFS is installed on the worker node!!"
else
	# if not, install CVMFS via mountrepo or cvmfsexec
	echo -e "\nCVMFS is NOT installed on the worker node! Installing now..."
	# check the operating system distro
	if [[ $OS_DISTRO = "rhel" ]]; then
		# check operating system and kernel info to decide what to use (cvmfsexec, mountrepo, etc.)
		evaluate_os_and_kernel $OS_VARIANT $KRNL_VER $KRNL_MAJOR_REV $KRNL_MINOR_REV $KRNL_PATCH_NUM
		res_mount=$?
		
		# depending on the previously caught exit status, perform next steps accordingly
		if [[ $res_mount -eq 1 ]]; then
			echo "Mounting CVMFS repositories..."
			mount_cvmfs_repos $CVMFS_CONFIG_REPO $CVMFS_REPOS
		else
			echo "Cannot mount CVMFS repositories!"
			exit 1
		fi	
	else	# OS_DISTRO = "non-rhel" (any non-rhel OS)
		print_os_info
		echo "This is a non-RHEL OS and is not covered in the implementation yet!"
		# ----- THINK ABOUT THIS FURTHER ----- #
	fi

fi

df -h | grep /cvmfs &> /dev/null
if [[ $? -eq 0 ]]; then
	echo -e "CVMFS repositories mounted\n"
	# mimicking the behavior of the glidein on the worker node (start the user job once the CVMFS repositories are mounted)
	sh user_job.sh
else
	echo "Error occured during mount of CVMFS repositories\n"
fi

log_marker "END" "MOUNTING"

########################################################################################################
# This is the end of the main program.
#######################################################################################################

