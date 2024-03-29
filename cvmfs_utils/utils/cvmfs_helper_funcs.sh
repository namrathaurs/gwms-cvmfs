#!/bin/bash
# Project:
#	GlideinWMS
#
# 
# Description:
#	This script contains helper functions that support the mount/unmount of 
#	CVMFS on worker nodes.
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

# fetch the error reporting helper script
#error_gen=`grep '^ERROR_GEN_PATH ' $glidein_config | awk '{print $2}'`
#echo $error_gen

variables_reset() {
	# DESCRIPTION: This function lists and initializes the common variables
	# to empty strings. These variables also become available to scripts 
	# that import functions defined in this script.
	#
	# INPUT(S): None
	# RETURN(S): Variables initialized to empty strings
	
	# indicates whether the perform_system_check function has been run
	GWMS_SYSTEM_CHECK=

	# following set of variables used to store operating system and kernel info
	GWMS_OS_DISTRO=
	GWMS_OS_VERSION=
	GWMS_OS_KRNL_ARCH=
	GWMS_OS_KRNL_NUM=
	GWMS_OS_KRNL_VER=
	GWMS_OS_KRNL_MAJOR_REV=
	GWMS_OS_KRNL_MINOR_REV=
	GWMS_OS_KRNL_PATCH_NUM=
	
	# indicates whether CVMFS is locally mounted on the node
	GWMS_IS_CVMFS_MNT=
	# to indicate the status of mounting CVMFS by the glidein after evaluating the worker node
	GWMS_IS_CVMFS=

	# indicates if unpriv userns is available (or supported); not if it is enabled
	GWMS_IS_UNPRIV_USERNS_SUPPORTED=
	# indicates if unpriv userns is enabled (and available)
	GWMS_IS_UNPRIV_USERNS_ENABLED= 
	
	# following variables store FUSE-related information 
	GWMS_IS_FUSE_INSTALLED=
	GWMS_IS_FUSERMOUNT=
	GWMS_IS_USR_IN_FUSE_GRP=
}


loginfo() {
	# DESCRIPTION: This function prints informational messages to STDOUT
	# along with hostname and date/time.
	# 
	# INPUT(S): String containing the message
	# RETURN(S): Prints message to STDOUT

	echo -e "$(hostname -s) $(date +%m-%d-%Y\ %T\ %Z) \t INFO: $1" >&2
}


logwarn(){
	# DESCRIPTION: This function prints warning messages to STDOUT along
	# with hostname and date/time.
	#
	# INPUT(S): String containing the message 
	# RETURN(S): Prints message to STDOUT

	echo -e "$(hostname -s) $(date +%m-%d-%Y\ %T\ %Z) \t WARNING: $1" >&2
}


logerror() {
	# DESCRIPTION: This function prints error messages to STDOUT along with
	# hostname and date/time.
	#
        # INPUT(S): String containing the message
	# RETURN(S): Prints message to STDOUT

	echo -e "$(hostname -s) $(date +%m-%d-%Y\ %T\ %Z) \t ERROR: $1" >&2
}


check_exit_status () {
        # DESCRIPTION: This function prints an appropriate message to the
        # console to indicate what the exit status means.
        #
        # INPUT(S): Number (exit status of a previously run command)
        # RETURN(S): Prints "yes" or "no" to indicate the result of the command

	[[ $1 -eq 0 ]] && echo yes || echo no
}

detect_local_cvmfs() {
	CVMFS_ROOT="/cvmfs"
	repo_name=oasis.opensciencegrid.org
	# Second check...
	if [[ -f $CVMFS_ROOT/$repo_name/.cvmfsdirtab || "$(ls -A $CVMFS_ROOT/$repo_name)" ]] &>/dev/null
	then
		loginfo "Validating CVMFS with ${repo_name}..."
		true
	else
		logwarn "Validating CVMFS with ${repo_name}: directory empty or does not have .cvmfsdirtab"
		false
	fi
	
	GWMS_IS_CVMFS_MNT=$?
	loginfo "CVMFS locally installed: $(check_exit_status $GWMS_IS_CVMFS_MNT)"
}

perform_system_check() {
        # DESCRIPTION: This functions performs required system checks (such as
        # operating system and kernel info, unprivileged user namespaces, FUSE
        # status) and stores the results in the common variables for later use.
        #
        # INPUT(S): None
        # RETURN(S): 
	# 	-> common variables containing the exit status of the
	# 	corresponding commands
	# 	-> results from running the check_exit_status function
	# 	for logging purposes (variables starting with res_)
	# 	-> assigns "yes" to GWMS_SYSTEM_CHECK to indicate this function
	# 	has been run.

	if [ -f '/etc/redhat-release' ]; then
		GWMS_OS_DISTRO=rhel
	else
		GWMS_OS_DISTRO=non-rhel
	fi
	
	GWMS_OS_VERSION=`lsb_release -r | awk -F'\t' '{print $2}'`
	GWMS_OS_KRNL_ARCH=`arch`
	GWMS_OS_KRNL_NUM=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " `
	GWMS_OS_KRNL_VER=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " | awk -F'.' '{print $1}'`
	GWMS_OS_KRNL_MAJOR_REV=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " | awk -F'.' '{print $2}'`
	GWMS_OS_KRNL_MINOR_REV=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 1 -d " " | awk -F'.' '{print $3}'`
	GWMS_OS_KRNL_PATCH_NUM=`uname -r | awk -F'-' '{split($2,a,"."); print $1,a[1]}' | cut -f 2 -d " "`
	
	#df -h | grep /cvmfs &>/dev/null
	#GWMS_IS_CVMFS_MNT=$?
	# call function to detect local CVMFS only if the GWMS_IS_CVMFS_MNT variable is not set; if the variable is not empty, do nothing
	[[ -z "${GWMS_IS_CVMFS_MNT}" ]] && detect_local_cvmfs || :
	
	sysctl user.max_user_namespaces &>/dev/null
	GWMS_IS_UNPRIV_USERNS_SUPPORTED=$?
	
	unshare -U true &>/dev/null
	GWMS_IS_UNPRIV_USERNS_ENABLED=$?
	
	yum list installed *fuse* &>/dev/null
	GWMS_IS_FUSE_INSTALLED=$?

	fusermount -V &>/dev/null
        GWMS_IS_FUSERMOUNT=$?

	getent group fuse | grep $USER &>/dev/null
	GWMS_IS_USR_IN_FUSE_GRP=$?
	
	# set the variable indicating this function has been run
	GWMS_SYSTEM_CHECK=yes

}


print_os_info () {
        # DESCRIPTION: This functions prints operating system and kernel
        # information to STDOUT.
        #
        # INPUT(S): None
        # RETURN(S): Prints a message containing OS and kernel details

        loginfo "Found $GWMS_OS_DISTRO${GWMS_OS_VERSION}-${GWMS_OS_KRNL_ARCH} with kernel $GWMS_OS_KRNL_NUM-$GWMS_OS_KRNL_PATCH_NUM"
}


log_all_system_info () {
        # DESCRIPTION: This function prints all the necessary system information
        # stored in common and result variables (see perform_system_check
        # function) for easy debugging. This has been done as collecting
        # information about the worker node can be useful for troubleshooting
        # and gathering stats about what is out there.
        #
        # INPUT(S): None
        # RETURN(S): Prints user-friendly messages to STDOUT

	loginfo "..."
	loginfo "Worker node details: "	
	loginfo "Operating system distro: $GWMS_OS_DISTRO"
	loginfo "Operating System version: $GWMS_OS_VERSION"
	loginfo "Kernel Architecture: $GWMS_OS_KRNL_ARCH"
	loginfo "Kernel version: $GWMS_OS_KRNL_VER"
	loginfo "Kernel major revision: $GWMS_OS_KRNL_MAJOR_REV"
	loginfo "Kernel minor revision: $GWMS_OS_KRNL_MINOR_REV"
	loginfo "Kernel patch number: $GWMS_OS_KRNL_PATCH_NUM"
	
	loginfo "CVMFS locally installed: $(check_exit_status $GWMS_IS_CVMFS_MNT)"
	loginfo "Unprivileged user namespaces supported: $(check_exit_status $GWMS_IS_UNPRIV_USERNS_SUPPORTED)"
	loginfo "Unprivileged user namespaces enabled: $(check_exit_status $GWMS_IS_UNPRIV_USERNS_ENABLED)"
	loginfo "FUSE installed: $(check_exit_status $GWMS_IS_FUSE_INSTALLED)"
	loginfo "fusermount available: $(check_exit_status $GWMS_IS_FUSERMOUNT)"
	loginfo "Is the user in 'fuse' group: $(check_exit_status $GWMS_IS_USR_IN_FUSE_GRP)"
	loginfo "..."
}


mount_cvmfs_repos () {
        # DESCRIPTION: This function mounts all the required and additional
        # CVMFS repositories that would be needed for user jobs.
        #
        # INPUT(S): 1. CVMFS configuration repository (string); 2. Additional CVMFS
        # repositories (colon-delimited string)
        # RETURN(S): Mounts the defined repositories on the worker node filesystem

	# QUESTION FOR MARCO
	# see if the utilities are available (in the hidden directory) from the previous mount activity on the worker node
	# this is not possible since this script is run once at the time of glidein creation on the worker node - is that right???
	#if [[ ! -d $cvmfs_utils_dir/.cvmfsexec ]]; then
	#	$cvmfs_utils_dir/mycvmfsexec -- echo "CVMFS utilities available" &> /dev/null
	#	echo "executing inside"
	#fi
	
	#$cvmfs_utils_dir/mycvmfsexec $1 -- echo "setting up mount utilities..." &> /dev/null
	$cvmfs_utils_dir/distros/$dist_file $1 -- echo "setting up mount utilities..." &> /dev/null
	if [[ $(df -h|grep /cvmfs|wc -l) -eq 1 ]]; then
		loginfo "CVMFS config repo already mounted!"
		continue
	else
		# mounting the configuration repo (pre-requisite)
		loginfo "Mounting CVMFS config repo now..."
		$cvmfs_utils_dir/distros/.cvmfsexec/mountrepo $1
		#.cvmfsexec/mountrepo $1
	fi
	
	# using an array to unpack the names of additional CVMFS repositories
	# from the colon-delimited string
	declare -a cvmfs_repos
	repos=($(echo $2 | tr ":" "\n"))
	#echo ${repos[@]}       
	
	loginfo "Mounting additional CVMFS repositories..."
	# mount every repository that was previously unpacked
	for repo in "${repos[@]}"
	do
		$cvmfs_utils_dir/distros/.cvmfsexec/mountrepo $repo
	#	.cvmfsexec/mountrepo $repo
	done

	# see if all the repositories got mounted
	num_repos_mntd=`df -h | grep /cvmfs | wc -l`
	total_num_repos=$(( ${#repos[@]} + 1 ))
	if [ "$num_repos_mntd" -eq "$total_num_repos" ]; then
	#if [ "$num_repos_mntd" -eq 2 ]; then
		loginfo "All CVMFS repositories mounted successfully on the worker node"
		true
	else
		logwarn "One or more CVMFS repositories might not be mounted on the worker node"
		false
	fi
	
	GWMS_IS_CVMFS=$?
}


has_unpriv_userns() {
        # DESCRIPTION: This function checks the status of unprivileged user
        # namespaces being supported and enabled on the worker node. Depending 
        #
        # INPUT(S): None
        # RETURN(S): 
	#	-> true (0) if unpriv userns can be used (supported and enabled),
	#	false otherwise
	#	-> status of unpriv userns (unavailable, disabled, enabled,
	#	error) to stdout

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
			logerror "Inconsistent system configuration: unprivileged userns is enabled but not supported" 
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
        # DESCRIPTION: This function checks FUSE-related configurations on the
        # worker node. This is a pre-requisite before evaluating whether CVMFS
        # is mounted on the filesystem.
        # 
        # FUSE Documentation references:
	# https://www.kernel.org/doc/html/latest/filesystems/fuse.html
        # https://en.wikipedia.org/wiki/Filesystem_in_Userspace
        #
        # INPUT(S): None
        # RETURN(S): string denoting fuse availability (yes, no, error)

	# make sure that perform_system_check has run
	[[ -n "${GWMS_SYSTEM_CHECK}" ]] && perform_system_check
	
	#GWMS_IS_FUSERMOUNT=0
	#res_is_fusermount=$(check_exit_status $GWMS_IS_FUSERMOUNT)
	#loginfo "fusermount available: $res_is_fusermount"

	# check what specific configuration of unprivileged user namespaces exists in the system (worker node)
	unpriv_userns_config=$(has_unpriv_userns)
	
	# exit from the script if unprivileged namespaces are not supported but enabled in the kernel
	if [[ "${unpriv_userns_config}" == error ]]; then
		"$error_gen" -error "`basename $0`" "WN_Resource" "Unprivileged user namespaces are not supported but enabled in the kernel! Check system configuration."
		exit 1
	# determine if mountrepo/umountrepo could be used by checking availability of fuse, fusermount and user being in fuse group...
	elif [[ "${GWMS_IS_FUSE_INSTALLED}" -eq 0 ]]; then
		# fuse is installed
		if [[ $unpriv_userns_config == unavailable ]]; then
			# unprivileged user namespaces unsupported, i.e. kernels 2.x (scenarios 5b,6b)
			if [[ "${GWMS_IS_USR_IN_FUSE_GRP}" -eq 0 ]]; then
				# user is in fuse group -> fusermount is available (scenario 6b)
                                if [[ "${GWMS_IS_FUSERMOUNT}" -ne 0 ]]; then
                                        logwarn "Inconsistent system configuration: fusermount is available with fuse installed and when user is in fuse group"
                                        echo error
                                else
                                        loginfo "FUSE requirements met by the worker node"
                                        echo yes
                                fi
                        else
                                # user is not in fuse group -> fusermount is unavailable (scenario 5b)
				if [[ "${GWMS_IS_FUSERMOUNT}" -eq 0 ]]; then
                                        logwarn "Inconsistent system configuration: fusermount is available only when user is in fuse group and fuse is installed"
                                        echo error
                                else
                                        loginfo "FUSE requirements not satisfied: user is not in fuse group"
                                        echo no
                                fi				
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
        # DESCRIPTION: This function evaluates the worker using FUSE and
        # unpriv. userns configurations to determine whether CVMFS can be
        # mounted using mountrepo utility.
        #
        # INPUT(S): None
        # RETURN(S): string message whether CVMFS can be mounted 

	# collect info about FUSE configuration on the worker node
	fuse_config_status=$(has_fuse)	

	# check fuse related configurations in the system (worker node)
	if [[ $fuse_config_status == yes ]]; then
		# success;
		loginfo "CVMFS can be mounted and unmounted on the worker node using mountrepo/umountrepo utility"
		true
	elif [[ $fuse_config_status == no ]]; then
		# failure;
		logerror "CVMFS cannot be mounted on the worker node using mountrepo utility"
		false
	elif [[ $fuse_config_status == error ]]; then
		# inconsistent system configurations detected in the worker node
		logerror "Detected inconsistent configurations on the worker node. mountrepo utility cannot be used!!"
		false	
	fi
		
}	
