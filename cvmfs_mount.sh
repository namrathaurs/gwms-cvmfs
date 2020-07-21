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
#LOGFILE="script.log"
#exec &> $LOGFILE

perform_system_check () {
	# perform required system checks (OS variant, kernel version, unprivileged userns, and others) and store the results in variables for later use
	if [ -f '/etc/redhat-release' ]; then
		OS_DISTRO="rhel"
	else
		OS_DISTRO="non-rhel"
	fi
	
	OS_VARIANT="$(lsb_release -r | awk -F'\t' '{print $2}')"
	KRNL_NUM=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " `
	KRNL_VER=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " | awk -F'.' '{print $1}'`
	KRNL_MAJOR_REV=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " | awk -F'.' '{print $2}'`
	KRNL_MINOR_REV=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " | awk -F'.' '{print $3}'`
	KRNL_PATCH_NUM=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 2 -d " "`
	
	df -h | grep /cvmfs &>/dev/null 
	IS_CVMFS_MNT=$?
	
	unshare -U true &>/dev/null
	IS_UNPRIV_USERNS_1=$?
	
	sysctl user.max_user_namespaces &>/dev/null
	IS_UNPRIV_USERNS_2=$?
	
	fusermount -V &>/dev/null
	IS_FUSERMOUNT=$?

	yum list installed *fuse* &>/dev/null
	IS_FUSE_INSTALLED=$?

	getent group fuse | grep $USER &>/dev/null
	IS_USR_IN_FUSE_GRP=$?
	
}

check_exit_status () {
	case $1 in
		"0")
		   echo -n "Yes";;
		*)
		   echo -n "No";;
	esac	
}

log_system_info () {
	# logs all required system information to the console
	
	# marker to indicate the start of log contents from the script execution
	echo "------------------------------- START OF LOG INFO ----------------------------------"
	
	
	# log the above variables (print to stderr) for easy debugging (collect info about the nodes that can be useful for troubleshooting and gather stats about what is out there)
	echo ""
	echo "Logging info from system checks..."
	case $OS_DISTRO in
     		"rhel")
        	    echo "Operating system distro: RHEL";;
     		"non-rhel")
        	    echo "Operating system distro: Non-RHEL";;
     		*)
	esac

	echo "Operating System version: $OS_VARIANT"
	echo "Kernel version: $KRNL_VER"
	echo "Kernel major revision: $KRNL_MAJOR_REV"
	echo "Kernel minor revision: $KRNL_MINOR_REV"
	echo "Kernel patch number: $KRNL_PATCH_NUM"
	
	echo "CVMFS installed:" $(check_exit_status $IS_CVMFS_MNT)
	echo "Unprivileged user namespaces enabled (via sysctl):" $(check_exit_status $IS_UNPRIV_USERNS_1)
	echo "Unprivileged user namespaces enabled (via unshare):" $(check_exit_status $IS_UNPRIV_USERNS_2)
	echo "fusermount available:" $(check_exit_status $IS_FUSERMOUNT)
	echo "FUSE installed:" $(check_exit_status $IS_FUSE_INSTALLED)
	echo "Is the user in 'fuse' group:" $(check_exit_status $IS_USR_IN_FUSE_GRP)
}

function mount_cvmfs_repos {
	echo "Hello World from inside cvmfsexec"
	
	cvmfsexec/mountrepo $CVMFS_CONFIG_REPO
	declare -a cvmfs_repos
	repos=($(echo $CVMFS_REPOS | tr ":" "\n"))
	#echo ${repos[@]}       
	
	for repo in "${repos[@]}"
	do
		cvmfsexec/mountrepo $repo
	done

}



########################################################################################################
#
# This is the start of the main program...
#
########################################################################################################

perform_system_check

log_system_info

# initializing the repos for CVMFS
CVMFS_CONFIG_REPO=cvmfs-config.cern.ch
REPOS=config-osg.opensciencegrid.org:singularity.opensciencegrid.org:cms.cern.ch
# set an environment variable that neds to be mounted after config repos are mounted
export CVMFS_REPOS=$REPOS

# detect if CVMFS is installed (using the global variable)
if [ $IS_CVMFS_MNT -eq 0 ]; then
	# do nothing (if CVMFS is installed)
	echo "CVMFS is installed on the worker node!!"
else
	# if not, install CVMFS via mountrepo or cvmfsexec
	echo "CVMFS is NOT installed on the worker node! Installing now..."
	# check the operating system distro
	if [[ $OS_DISTRO = "rhel" ]]; then
		# check operating system and kernel info to decide what to use (cvmfsexec, mountrepo, etc.)
		if [[ $(echo "$OS_VARIANT==7.8" | bc -l) && $KRNL_VER -ge 3 && $KRNL_MAJOR_REV -ge 10 && $KRNL_MINOR_REV -ge 0 && $KRNL_PATCH_NUM -ge 1127 ]]; then
			echo "Found $OS_DISTRO $OS_VARIANT with $KRNL_NUM-$KRNL_PATCH_NUM"
			# check for unprivileged user namespaces
			if [[ $IS_UNPRIV_USERNS_1 -eq 0 && $IS_UNPRIV_USERNS_2 -eq 0 ]]; then
				echo "unprivileged user namespaces is enabled"
				# instead of using cvmfsexec, use mountrepo/umountrepo to mount cvmfs repos since cvmfsexec modifies the execution environment"
				if [[ $IS_FUSERMOUNT -eq 0 && $IS_FUSE_INSTALLED -eq 0 ]]; then
                                        echo "fuse/fusermount available"
                                        echo "use mountrepo/umountrepo to mount cvmfs repos"
					mount_cvmfs_repos
					df -h
                                else
					echo "only cvmfsexec can be used to mount cvmfs repos"
					#./mycvmfsexec $CVMFS_CONFIG_REPO -- $SHELL command_test.sh
					#if [[ $? -eq 1 && -z "$CVMFSMOUNT" ]]; then
					#	echo "Outside of cvmfsexec"
					#fi
				fi
			else	# either IS_UNPRIV_USERNS_1 != 0, IS_UNPRIV_USERNS_2 != 0 or both
				# unprivileged user namespaces is disabled
				echo "unprivileged user namespaces is disabled"
				if [[ $IS_FUSERMOUNT -eq 0 && $IS_FUSE_INSTALLED -eq 0 ]]; then
					echo "use mountrepo/umountrepo to mount cvmfs repos"
					mount_cvmfs_repos
					df -h
				else
					# ----- THINK ABOUT THIS FURTHER (fusermount/fuse not available!) -----
					echo "not possible to mount cvmfs repos... find an alternative??"
				fi
			fi
		elif [[ $(echo "$OS_VARIANT==7.6" | bc -l) ]]; then
			echo "Found $OS_DISTRO $OS_VARIANT with $KRNL_NUM-$KRNL_PATCH_NUM"
			# check for unprivileged user namespaces
			if [[ $IS_UNPRIV_USERNS_1 -eq 0 && $IS_UNPRIV_USERNS_2 -eq 0 ]]; then
				if [[ $IS_FUSERMOUNT -eq 0 ]]; then
					# unprivileged user namespaces is enabled and fusermount is available
					echo "use cvmfsexec to mount cvmfs repos"
				else
					# unprivileged user namespaces is enabled and fusermount is not available
					echo "----- THINK ABOUT THIS FURTHER ----"
				fi
			else	# either IS_UNPRIV_USERNS_1 != 0, IS_UNPRIV_USERNS_2 != 0 or both
				# unprivileged user namespaces is disabled
				echo "use mountrepo/umountrepo to mount cvmfs repos"
			fi

		elif [[ $(echo "$OS_VARIANT>=6.0 && $OS_VARIANT<=7.0" | bc -l) ]]; then
                        echo "Found $OS_DISTRO $OS_VARIANT with $KRNL_NUM-$KRNL_PATCH_NUM"
                        if [[ $IS_UNPRIV_USERNS_1 -ne 0 && $IS_UNPRIV_USERNS_2 -ne 0 ]]; then
                                # no unprivileged user namespaces; RHEL6 does not have userns and no new development is happening (also EOL in Nov 2020)
                                echo "unprivileged user namespaces are not available"
                                if [[ $IS_FUSE_INSTALLED -eq 0 && $IS_USER_IN_FUSE_GRP -eq 0 ]]; then
                                        # fuse is installed and user is in 'fuse' group
                                        echo "use mountrepo/umountrepo to mount cvmfs repos"
                                	mount_cvmfs_repos
					df -h
				else    # either fuse is not installed or user is not in 'fuse' group or both
                                        echo "----- THINK ABOUT THIS FURTHER -----"
                                fi
                        else    # unprivileged user namespaces are enabled 
                                echo "is this even a possibility given EOL in Nov 2020????"
                        fi

		elif [[ $(echo "$OS_VARIANT==8" | bc -l) && $KRNL_VER -ge 4 && $KRNL_MAJOR_REV -ge 18 ]]; then
			echo "Found $OS_DISTRO $OS_VARIANT with $KRNL_NUM-$KRNL_PATCH_NUM"
			# unprivileged user namespaces are enabled (by default)
			echo "use cvmfsexec to mount cvmfs repos"
		else # some other case not covered!
			echo "Found $OS_DISTRO $OS_VARIANT with $KRNL_NUM-$KRNL_PATCH_NUM"
		fi   
	else	# OS_DISTRO = "non-rhel" (any non-rhel OS)
		echo "Found $OS_DISTRO $OS_VARIANT with $KRNL_NUM-$KRNL_PATCH_NUM"
		# ----- THINK ABOUT THIS FURTHER ----- #
	fi
	#exec > tmp
	#./mycvmfsexec $CVMFS_CONFIG_REPO -- $SHELL command_test.sh 	
	#exit

fi

df -h | grep /cvmfs &> /dev/null
if [[ $? -eq 0 ]]; then
	echo "CVMFS repositories mounted"
	sh user_job.sh
else
	echo "Error occured during mount of CVMFS repositories"
fi


# marker to indicate the end of log contents from the script execution
echo -e "\n------------------------------- END OF LOG INFO --------------------------------------"
