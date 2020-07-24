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



# to implement custom logging
# https://stackoverflow.com/questions/42403558/how-do-i-manage-log-verbosity-inside-a-shell-script
# WORKAROUND: redirect stdout and stderr to some file 
#LOGFILE="cvmfs_all.log"
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
	#echo "IS_UNPRIV_USERNS1: $IS_UNPRIV_USERNS_1"
	
	sysctl user.max_user_namespaces &>/dev/null
	IS_UNPRIV_USERNS_2=$?
	#echo "IS_UNPRIV_USERNS2: $IS_UNPRIV_USERNS_2"
	
	fusermount -V &>/dev/null
	IS_FUSERMOUNT=$?

	yum list installed *fuse* &>/dev/null
	IS_FUSE_INSTALLED=$?

	getent group fuse | grep $USER &>/dev/null
	IS_USR_IN_FUSE_GRP=$?
	
}

log_marker () {
        # marker to indicate the start/end of log contents from the script executio
        # input: (1) string indicating start or end log marker, (2) string indicating logging for mounting or unmounting		
	# return value: None
	
	echo -e "\n------------------------------- $1 OF LOG INFO FOR $2 CVMFS --------------------------------------\n"
}

check_exit_status () {
	# checks exit status and prints appropriate message to the console
	# input: variable containing system information (created in the perform_system_check function)
	# return value: None
	
	case $1 in
		"0")
		   echo -n "Yes";;
		*)
		   echo -n "No";;
	esac	
}

check_os_distro () {
	# checks operating system distribution and prints appropriate message to the console
	# input: variable containing operating system distribution information
	# return value: None
	
        case $1 in
                "rhel")
                    echo -n "RHEL";;
                "non-rhel")
                    echo -n "Non-RHEL";;
                *)
        esac
}

log_system_info () {
	# logs all required system information stored in variables (print to stderr) for easy debugging
	# collecting information about the nodes can be useful for troubleshooting and gathering stats about what is out there
	
	echo "Logging info from system checks..."
	echo "Operating system distro:" $(check_os_distro $OS_DISTRO)
	echo "Operating System version: $OS_VARIANT"
	echo "Kernel version: $KRNL_VER"
	echo "Kernel major revision: $KRNL_MAJOR_REV"
	echo "Kernel minor revision: $KRNL_MINOR_REV"
	echo "Kernel patch number: $KRNL_PATCH_NUM"
	
	echo "CVMFS installed:" $(check_exit_status $IS_CVMFS_MNT)
	echo "Unprivileged user namespaces enabled (via unshare):" $(check_exit_status $IS_UNPRIV_USERNS_1)
	echo "Unprivileged user namespaces enabled (via sysctl):" $(check_exit_status $IS_UNPRIV_USERNS_2)
	echo "fusermount available:" $(check_exit_status $IS_FUSERMOUNT)
	echo "FUSE installed:" $(check_exit_status $IS_FUSE_INSTALLED)
	echo "Is the user in 'fuse' group:" $(check_exit_status $IS_USR_IN_FUSE_GRP)
}

function mount_cvmfs_repos {
	# mounts all the required CVMFS repositories
	# input: (1) CVMFS configuration repository, (2) CVMFS repositories
        # return value: None
		
	cvmfsexec/mountrepo $1
	declare -a cvmfs_repos
	repos=($(echo $2 | tr ":" "\n"))
	#echo ${repos[@]}       
	
	for repo in "${repos[@]}"
	do
		cvmfsexec/mountrepo $repo
	done

	echo ""	
	# see if the repositories got mounted
	df -h
}


print_os_info () {
	# prints operating system information along with kernel number
	
	echo "Found $OS_DISTRO $OS_VARIANT with $KRNL_NUM-$KRNL_PATCH_NUM" 
}

check_unpriv_userns () {
	# checks whether unprivileged user namespaces are enabled or not and sets a flag
	# input: two variables that denote whether unprivileged user namespaces is enabled (based on unshare and sysctl commands)
	# return value: numeric flag denoting the combination of the inputs
		
	local func_res
        if [[ $1 -eq 0 && $2 -eq 0 ]]; then
                func_res=1
	elif [[ $1 -ne 0 && $2 -eq 0 ]]; then
		func_res=2
        elif [[ $1 -eq 0 && $2 -ne 0 ]]; then
		func_res=3 
	else
                func_res=0
        fi

	echo $func_res
}

check_fuse () {
	# checks whether (1) fuse is installed and/or (2) fusermount is available and sets a flag
	# input: (1) variable denoting fuse installation and (2) variable denoting availability of fusermount
	# return value: numeric flag denoting the combination of the inputs
	
	local func_res
        if [[ $1 -eq 0 && $2 -eq 0 ]]; then
                func_res=1
        elif [[ $1 -eq 0 && $2 -ne 0 ]]; then
		func_res=2
	else 
                func_res=0
        fi

	echo $func_res
}

check_fuse_usr () {
	# checks whether the user running this script in the 'fuse' group and sets a flag
	# input: variable that stores 'fuse' group information for the user
	# return value: numeric flag denoting the user in 'fuse' group

	local func_res
	if [[ $1 -eq 0 ]]; then
		func_res=1
	else
		func_res=0
	fi

	echo $func_res
}

evaluate_os_and_kernel () {
	# evaluates what option to use to mount CVMFS repositories on the system given the OS version and the kernel number
	# input: (1) OS version and kernel number [(2) version, (3) major revision, (4) minor revision and (5) patch number)]
	# return value: flag indicating whether CVMFS repositories can be mounted with mountrepo utility
	
	local mount_flag=0
	res_unpriv_userns=$(check_unpriv_userns $IS_UNPRIV_USERNS_1 $IS_UNPRIV_USERNS_2)
	res_fuse=$(check_fuse $IS_FUSE_INSTALLED $IS_FUSERMOUNT)
	res_fuse_usr=$(check_fuse_usr $IS_USR_IN_FUSE_GRP)
	
	case $1 in
		8"."[0-9]*)
			echo $1 
			required_krnl_ver=4 ; required_krnl_majorrev=18
			expr1=$(( $2 >= required_krnl_ver ))
			expr2=$(( $3 >= required_krnl_majorrev ))
			echo $expr1, $expr2
			if [[ $expr1 -eq 1 && $expr2 -eq 1 ]]; then
                                print_os_info
				# unprivileged user namespaces are enabled (by default); cvmfsexec works too!
				echo "Using mountrepo to mount CVMFS repos..." 
				mount_flag=1	
                        else	# kernel number  < 4.18
                                echo "check if mountrepo/umountrepo can be used" 
                        fi
                        ;;	
		
		7"."[0-9]* | 6\.*)
			required_krnl_ver=3 ; required_krnl_majorrev=10 ; required_krnl_minorrev=0 ; required_krnl_patchnum=1127  
			expr1=$(( $2 >= $required_krnl_ver ))
			expr2=$(( $3 >= $required_krnl_majorrev ))
			expr3=$(( $4 >= $required_krnl_minorrev ))
			expr4=$(( $5 >= $required_krnl_patchnum ))
			#echo $expr1, $expr2, $expr3, $expr4
			if [[ $expr1 -eq 1 && $expr2 -eq 1 && $expr3 -eq 1 && $expr4 -eq 1 ]]; then
				# RHEL >= 7.8
				print_os_info
				#echo $res_unpriv_userns, $res_fuse, $res_fuse_usr
				if [[ $res_unpriv_userns -eq 1 ]]; then
					echo "unprivileged user namespaces (both) are enabled" 
					if [[ $res_fuse -eq 1 && ( $res_fuse_usr -eq 0 || $res_fuse_usr -eq 1 ) ]]; then
						echo "fuse/fusermount available and user is/is not in fuse group" 
						echo "Using mountrepo/umountrepo to mount CVMFS repos..." 
						mount_flag=1
					elif [[ $res_fuse -eq 0 && ( $res_fuse_usr -eq 0 || $res_fuse_usr -eq 1 ) ]]; then
						echo "CVMFS can be mounted by cvmfsexec only!!" 
					else
						echo "CVMFS cannot be mounted by mountrepo/umountrepo!!" 
					fi
				elif [[ $res_unpriv_userns -eq 2 ]]; then  #|| $res_unpriv_userns==3 )); then
					echo "unprivileged user namespaces (via sysctl) is enabled" 
					if [[ $res_fuse -eq 0 && ( $res_fuse_usr -eq 0 || $res_fuse_usr -eq 1 ) ]]; then
						echo "CVMFS repos cannot be mounted by either cvmfsexec or mountrepo!!" 
					else
						echo "Using mountrepo/umountrepo to mount CVMFS repos..." 
						mount_flag=1
					fi
				fi
			else
				# RHEL <= 7.7
				if [[ $1 =~ 7\.[0-7] || $1 =~ 6\.[0-9][0-9] ]]; then
					echo "OS version $1 is between 6.0 and 7.7" 
				fi
                                print_os_info
                                #echo $res_unpriv_userns, $res_fuse, $res_fuse_usr 
                                if [[ $res_unpriv_userns -eq 0 ]]; then
                                        # no unprivileged user namespaces; RHEL6 does not have userns and no new development is happening (also EOL in Nov 2020)
                                        echo "unprivileged user namespaces (both) are not enabled" 
                                        if [[ $res_fuse -eq 2 || ( $res_fuse -eq 0 && ( $res_fuse_usr -eq 0 || $res_fuse_usr -eq 1 )) ]]; then
                                                echo "CVMFS cannot be mounted by either cvmfsexec or mountrepo!!" 
                                        elif [[ $res_fuse -eq 1 ]]; then
                                                echo "Using mountrepo/umountrepo to mount CVMFS repos..." 
                                        	mount_flag=1
					fi
                                else
                                        # unprivileged user namespaces are enabled 
                                        echo "unprivileged user namespaces are enabled, despite RHEL6 EOL in Nov 2020!!" 
                                fi  
	
			fi 
			;;
		
		*)
			echo "Handling other possible cases (default)..." 
			echo "OS version: $1" 
			;;	
	esac

	#echo $mount_flag 
	return $mount_flag
}
