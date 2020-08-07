#!/bin/bash
# Project:
#	GlideinWMS
#
# 
# Description:
#	This script contains helper functions that support the mount/unmount of CVMFS on worker nodes.
#
#
# Used by:
#	cvmfs_mount.sh, cvmfs_unmount.sh
#
# Author:
#	Namratha Urs
#
# Version:
#	1.0
#



# to implement custom logging
# https://stackoverflow.com/questions/42403558/how-do-i-manage-log-verbosity-inside-a-shell-script
# WORKAROUND: redirect stdout and stderr to some file 
#LOGFILE="cvmfs_all.log"
#exec &> $LOGFILE

variables_reset() {
	# not really used, mainly to list the common variables
	GWMS_SYSTEM_CHECK=				# used to indicate whether the perform_system_check function has been run
	GWMS_OS_DISTRO=
	GWMS_OS_VARIANT=
	GWMS_OS_KRNL_NUM=
	GWMS_OS_KRNL_VER=
	GWMS_OS_KRNL_MAJOR_REV=
	GWMS_OS_KRNL_MINOR_REV=
	GWMS_OS_KRNL_PATCH_NUM=
	GWMS_IS_CVMFS_MNT=
	GWMS_IS_CVMFS=
	GWMS_IS_UNPRIV_USERNS_SUPPORTED=   		# used to check if unpriv userns is available (or supported); not if it is enabled
	GWMS_IS_UNPRIV_USERNS_ENABLED=   		# used to check if unpriv userns is enabled (and available)
	GWMS_IS_FUSERMOUNT=
	GWMS_IS_FUSE_INSTALLED=
	GWMS_IS_USR_IN_FUSE_GRP=
}

loginfo() {
        # return 0 if not verbose (needed for bats test), print to stderr if verbose
        #[[ -z "$VERBOSE" ]] && return
	echo -e "$(hostname -s) $(date +%m-%d-%Y\ %T\ %Z) \t INFO: $1" >&2
}

logwarn(){
	echo -e "$(hostname -s) $(date +%m-%d-%Y\ %T\ %Z) \t WARNING: $1" >&2
}

logerror() {
	echo -e "$(hostname -s) $(date +%m-%d-%Y\ %T\ %Z) \t ERROR: $1" >&2
}


log_marker() {
        # marker to indicate the start/end of log contents from the script executio
        # input: (1) string indicating start or end log marker, (2) string indicating logging for mounting or unmounting                
        # return value: None

        #echo -e "\n------------------------------- $1 OF LOG INFO FOR $2 CVMFS --------------------------------------\n"
        echo "${1}ing log for ${2}ing CVMFS"
}


check_exit_status () {
        # checks exit status and prints appropriate message to the console
        # input: variable containing system information (created in the perform_system_check function)
        # return value: None

        case $1 in
                "0")
                   echo yes;;
                *)
                   echo no;;
        esac
}

#check_os_distro () {
        # checks operating system distribution and prints appropriate message to the console
        # input: variable containing operating system distribution information
        # return value: None

#        case $1 in
#                "rhel")
#                    echo "RHEL";;
#                "non-rhel")
#                    echo "Non-RHEL";;
#                *)
#        esac
#}



perform_system_check() {
	# perform required system checks (OS variant, kernel version, unprivileged userns, and others) and store the results in variables for later use
	
	if [ -f '/etc/redhat-release' ]; then
		GWMS_OS_DISTRO=RHEL
	else
		GWMS_OS_DISTRO=Non-RHEL
	fi
	
	GWMS_OS_VARIANT=`lsb_release -r | awk -F'\t' '{print $2}'`
	GWMS_OS_KRNL_NUM=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " `
	GWMS_OS_KRNL_VER=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " | awk -F'.' '{print $1}'`
	GWMS_OS_KRNL_MAJOR_REV=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " | awk -F'.' '{print $2}'`
	GWMS_OS_KRNL_MINOR_REV=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " | awk -F'.' '{print $3}'`
	GWMS_OS_KRNL_PATCH_NUM=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 2 -d " "`
	
	df -h | grep /cvmfs &>/dev/null
	GWMS_IS_CVMFS_MNT=$?
	res_cvmfs_mnt=$(check_exit_status $GWMS_IS_CVMFS_MNT)
	
	sysctl user.max_user_namespaces &>/dev/null
	GWMS_IS_UNPRIV_USERNS_SUPPORTED=$?
	res_unpriv_userns_supported=$(check_exit_status $GWMS_IS_UNPRIV_USERNS_SUPPORTED)
	
	unshare -U true &>/dev/null
	GWMS_IS_UNPRIV_USERNS_ENABLED=$?
	res_unpriv_userns_enabled=$(check_exit_status $GWMS_IS_UNPRIV_USERNS_ENABLED)
	
	yum list installed *fuse* &>/dev/null
	GWMS_IS_FUSE_INSTALLED=$?
	res_fuse_installed=$(check_exit_status $GWMS_IS_FUSE_INSTALLED)

	fusermount -V &>/dev/null
        GWMS_IS_FUSERMOUNT=$?
        res_fusermount=$(check_exit_status $GWMS_IS_FUSERMOUNT)

	getent group fuse | grep $USER &>/dev/null
	GWMS_IS_USR_IN_FUSE_GRP=$?
	res_usr_in_fuse_grp=$(check_exit_status $GWMS_IS_USR_IN_FUSE_GRP)
	
	# set the variable indicating this function has been run
	GWMS_SYSTEM_CHECK=yes

}

print_os_info () {
        # prints operating system information along with kernel number

        loginfo "Found $GWMS_OS_DISTRO${GWMS_OS_VARIANT} with kernel $GWMS_OS_KRNL_NUM-$GWMS_OS_KRNL_PATCH_NUM"
}

log_all_system_info () {
	# logs all required system information stored in variables (print to stderr) for easy debugging
	# collecting information about the nodes can be useful for troubleshooting and gathering stats about what is out there
	
	loginfo "..."
	loginfo "Worker node details: "	
	loginfo "Operating system distro: $GWMS_OS_DISTRO"
	loginfo "Operating System version: $GWMS_OS_VARIANT"
	loginfo "Kernel version: $GWMS_OS_KRNL_VER"
	loginfo "Kernel major revision: $GWMS_OS_KRNL_MAJOR_REV"
	loginfo "Kernel minor revision: $GWMS_OS_KRNL_MINOR_REV"
	loginfo "Kernel patch number: $GWMS_OS_KRNL_PATCH_NUM"
	
	loginfo "CVMFS installed: $res_cvmfs_mnt"
	loginfo "Unprivileged user namespaces supported: $res_unpriv_userns_supported"
	loginfo "Unprivileged user namespaces enabled: $res_unpriv_userns_enabled"
	loginfo "FUSE installed: $res_fuse_installed"
	loginfo "fusermount available: $res_fusermount"
	loginfo "Is the user in 'fuse' group: $res_usr_in_fuse_grp"
	loginfo "..."
}


mount_cvmfs_repos () {
	# mounts all the required CVMFS repositories
	# input: (1) CVMFS configuration repository, (2) CVMFS repositories
        # return value: None
	
	$cvmfs_utils_dir/.cvmfsexec/mountrepo $1
	
	declare -a cvmfs_repos
	repos=($(echo $2 | tr ":" "\n"))
	#echo ${repos[@]}       
	
	for repo in "${repos[@]}"
	do
		$cvmfs_utils_dir/.cvmfsexec/mountrepo $repo
	done

	loginfo ""	
	# see if the repositories got mounted
	df -h
}


has_unpriv_userns() {
	# checks whether unprivileged user namespaces are enabled or not and sets a flag
	# input: two variables that denote whether unprivileged user namespaces is enabled (based on unshare and sysctl commands)
	# return value: numeric flag denoting the combination of the inputs
	
	# Return true (0) if unprivileged user namespaces are available and enabled, false otherwise
	# Uses GWMS_IS_UNPRIV_USERNS_AVAILABLE and GWMS_IS_UNPRIV_USERNS_ENABLED (must run after perform_system_check())
	# return:
	#   0 if unpriv userns can be used (available and enabled)
	#   stdout: status of unpriv userns (unavailable, disabled, enabled, error)

	# make sure that perform_system_check has run	
	[[ -z "${GWMS_SYSTEM_CHECK}" ]] && perform_system_check

	# determine whether unprivileged user namespaces are supported and/or enabled...
	if [[ "${GWMS_IS_UNPRIV_USERNS_ENABLED}" -eq 0 ]]; then
		# unprivileged user namespaces is enabled
		if [[ "${GWMS_IS_UNPRIV_USERNS_SUPPORTED}" -eq 0 ]]; then
			# unprivileged user namespaces is supported
			loginfo "Unprivileged user namespaces supported and enabled"
			echo enabled
		else
			# unprivileged user namespaces is not supported
			logwarn "Inconsistent system configuration: unprivileged userns is enabled but not supported" 
        		echo error
		fi
		true
	else
		# unprivileged user namespaces is disabled
		if [[ "${GWMS_IS_UNPRIV_USERNS_SUPPORTED}" -eq 0 ]]; then
			# unprivileged user namespaces is supported
			logwarn "Unprivileged user namespaces disabled: can be enabled by the root user via sysctl" 
			echo disabled
		else
			# unprivileged user namespaces is not supported
			logwarn "Unprivileged user namespaces disabled and unsupported: can be supported/enabled only after a system upgrade"
			echo unavailable
		fi
		false
	fi

}

has_fuse() {
	# checks whether (1) fuse is installed and/or (2) fusermount is available and sets a flag
	# input: (1) variable denoting fuse installation and (2) variable denoting availability of fusermount
	# return value: numeric flag denoting the combination of the inputs
	
	# https://www.kernel.org/doc/html/latest/filesystems/fuse.html
	# https://en.wikipedia.org/wiki/Filesystem_in_Userspace       -- documentation purpose; free to include additional references
	# Left similar, probably should say if fuse can be used, calling it 'has_fuse'
	# should use also GWMS_IS_USR_IN_FUSE_GRP or the unprivileged userns variables?
	
	# Return true (0) if unprivileged user namespaces are available and enabled, false otherwise
	# Uses GWMS_IS_FUSERMOUNT, GWMS_IS_FUSE_INSTALLED (must run after perform_system_check())
	# checks whether (1) fuse is installed and/or (2) fusermount is available and sets a flag
	# return:
	#   0,1,2: numeric flag denoting the combination of the inputs
	#   stdout: word about fuse availability (both -fuse+fusermount-, fuse, no)

	# make sure that perform_system_check has run
	[[ -n "${GWMS_SYSTEM_CHECK}" ]] && perform_system_check

	# check what specific configuration of unprivileged user namespaces exists in the system (worker node)
	unpriv_userns_config=$(has_unpriv_userns)

	#GWMS_IS_FUSERMOUNT=1
	# determine if mountrepo/umountrepo could be used by checking availability of fuse, fusermount and user being in fuse group...
	if [[ "${GWMS_IS_FUSE_INSTALLED}" -eq 0 ]]; then
		# fuse is installed
		if [[ $unpriv_userns_config == unavailable ]]; then
			# unprivileged user namespaces unsupported, i.e. kernels 2.x (scenarios 5b,6b)
			if [[ "${GWMS_IS_USR_IN_FUSE_GRP}" -eq 0 ]]; then
				# user is in fuse group -> fusermount is available (scenario 6b)
				loginfo "FUSE requirements met by the worker node"
				echo yes
			else
				# user is not in fuse group -> fusermount is unavailable (scenario 5b)
				loginfo "FUSE requirements not satisfied: user is not in fuse group"
				echo no
			fi
		else
			# unprivileged user namespaces is either enabled or disabled
			if [[ "${GWMS_IS_FUSERMOUNT}" -eq 0 ]]; then
				# fusermount is available (scenarios 7,8)
				loginfo "FUSE requirements met by the worker node"
				echo yes
			else
				# fusermount is not available (scenarios 5a,6a)
				logwarn "Inconsistent system configuration: fusermount is available when fuse is installed "
				echo error
			fi
		fi
	else
		# fuse is not installed 
		if [[ "${GWMS_IS_FUSERMOUNT}" -eq 0 ]]; then
			# fusermount is somehow available and user is/is not in fuse group (scenarios 3,4)
			logwarn "Inconsistent system configuration: fusermount is only available with fuse and/or when user belongs to the fuse group"
			echo error
		else
			# fusermount is not available and user is/is not in fuse group (scenarios case 1,2)
			loginfo "FUSE requirements not satisfied: fusermount is not available"
			echo no
		fi
	fi

}



evaluate_worker_node_config () {
	# evaluates what option to use to mount CVMFS repositories on the system given the OS version and the kernel number
	# input: (1) OS version and kernel number [(2) version, (3) major revision, (4) minor revision and (5) patch number)]
	# return value: flag indicating whether CVMFS repositories can be mounted with mountrepo utility

	# only use has_unpriv_userns and has_fuse (user group too) for deterimning what option is possible to be used.
	# keep the kernel and OS info only for logging; understand the correlataion with the result of these methods to see if the tabulated association is accurate
	fuse_config_status=$(has_fuse)	

	# check fuse related configurations in the system (worker node)
	if [[ $fuse_config_status == yes ]]; then
		# success;
		loginfo "CVMFS can be mounted and unmounted on the worker node using mountrepo/umountrepo utility"
		true
	elif [[ $fuse_config_status == no ]]; then
		# failure;
		loginfo "CVMFS cannot be mounted on the worker node using mountrepo utility"
		false
	elif [[ $fuse_config_status == error ]]; then
		# inconsistent system configurations detected in the worker node
		logerror "Worker node does not satisfy requirements for using mountrepo utility"
		exit 1
	fi
		
}	
