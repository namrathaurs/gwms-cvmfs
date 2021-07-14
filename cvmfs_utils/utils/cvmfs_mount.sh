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


# fetch the error reporting helper script
error_gen=`grep '^ERROR_GEN_PATH ' $glidein_config | awk '{print $2}'`

# get the CVMFS requirement setting passed as one of the factory attributes
glidein_cvmfs=`grep '^GLIDEIN_CVMFS ' $glidein_config | awk '{print $2}'`
# make the attribute value case insensitive
glidein_cvmfs=${glidein_cvmfs,,}
# Alt this will work on older bash (like on Mac: 
# glidein_cvmfs=$(echo ${glidein_cvmfs} | tr [A-Z] [a-z])

# get the CVMFS source information from the factory attributes
cvmfs_source=`grep '^CVMFS_SRC ' $glidein_config | awk '{print $2}'`
# make the attribute value case insensitive
cvmfs_source=${cvmfs_source,,}

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

#cvmfs_source=osg
loginfo "CVMFS Source = $cvmfs_source"
# initializing CVMFS repositories to a variable for easy modification in the future
case $cvmfs_source in
	osg)
		GLIDEIN_CVMFS_CONFIG_REPO=config-osg.opensciencegrid.org
		GLIDEIN_CVMFS_REPOS=singularity.opensciencegrid.org:cms.cern.ch
	
		;;
		
	egi)
		GLIDEIN_CVMFS_CONFIG_REPO=config-egi.egi.eu
		GLIDEIN_CVMFS_REPOS=config-osg.opensciencegrid.org:singularity.opensciencegrid.org:cms.cern.ch
		;;
		
	default)
		GLIDEIN_CVMFS_CONFIG_REPO=cvmfs-config.cern.ch
		GLIDEIN_CVMFS_REPOS=config-osg.opensciencegrid.org:singularity.opensciencegrid.org:cms.cern.ch
		;;
	*)
		"$error_gen" -error "`basename $0`" "WN_Resource" "Invalid factory attribute value specified for CVMFS source."
		exit 1	
esac
# (optional) set an environment variable that suggests additional repos to be mounted after config repos are mounted
loginfo "CVMFS Config Repo = $GLIDEIN_CVMFS_CONFIG_REPO"

# detect if CVMFS is mounted (using the global variable created during perform_system_check)
if [ $GWMS_IS_CVMFS_MNT -eq 0 ]; then
	# do nothing (if CVMFS is available)
	loginfo "CVMFS is mounted on the worker node and available for use"
	# exit 0
	"$error_gen" -ok "`basename $0`"
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
		if [[ $glidein_cvmfs = never ]]; then
			# do nothing; test the node and print the results but do not even try to mount CVMFS
                        # just continue with glidein startup
                        echo $?
                        "$error_gen" -ok "`basename $0`" "Not trying to install CVMFS."
		else
			loginfo "Mounting CVMFS repositories..."
			if mount_cvmfs_repos $GLIDEIN_CVMFS_CONFIG_REPO $GLIDEIN_CVMFS_REPOS ; then
				#continue
                                ;
			else
				if [[ $glidein_cvmfs = required ]]; then
					# if mount CVMFS is not successful, report an error and exit with failure exit code
					echo $?
					"$error_gen" -error "`basename $0`" "WN_Resource" "CVMFS is required but unable to mount CVMFS on the worker node."
					exit 1
				elif [[ $glidein_cvmfs = preferred || $glidein_cvmfs = optional ]]; then
					# if mount CVMFS is not successful, report a warning/error in the logs and continue with glidein startup
					# script status must be OK, otherwise the glidein will fail 		
                        		echo $?
					"$error_gen" -ok "`basename $0`" "WN_Resource" "Unable to mount required CVMFS on the worker node. Continuing without CVMFS."
				else
					"$error_gen" -error "`basename $0`" "WN_Resource" "Invalid factory attribute value specified for CVMFS requirement."
					exit 1
				fi
			fi
		fi
	else
		# if evaluation was false, then exit from this activity of mounting CVMFS
		"$error_gen" -error "`basename $0`" "WN_Resource" "Worker node configuration did not pass the evaluation checks. CVMFS will not be mounted."
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
