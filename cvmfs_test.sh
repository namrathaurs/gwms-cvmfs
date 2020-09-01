#!/bin/bash

# first parameter passed to this script will always be the glidein configuration file (glidein_config)
glidein_config=$1

# fetch the error reporting helper script
error_gen=`grep '^ERROR_GEN_PATH ' $glidein_config | awk '{print $2}'`
#echo $error_gen

# get the glidein work directory location from glidein_config file
work_dir=`grep '^GLIDEIN_WORK_DIR ' $glidein_config | awk '{print $2}'`
#echo "Glidein Work Directory: $work_dir"

# get the CVMFS source information from <attr> in the glidein configuration 
cvmfs_source=`grep '^CVMFS_SRC ' $glidein_config | awk '{print $2}'`
#echo "CVMFS Source: $cvmfs_source"

# get the CVMFS requirement setting passed as one of the factory attributes
#glidein_cvmfs=`grep '^GLIDEIN_CVMFS ' $glidein_config | awk '{print $2}'
#echo $glidein_cvmfs

# store the directory location, to where the tarball is unpacked by the glidein, to a variable
cvmfs_utils_dir=$work_dir/cvmfs_utils
#echo "Glidein cvmfs_utils_dir: $cvmfs_utils_dir"

# $PWD=/tmp/glide_xxx and everypath is referenced with respect to $PWD
# source the helper script
source $cvmfs_utils_dir/utils/cvmfs_helper_funcs.sh

#perform_system_check

#os_like=$GWMS_OS_DISTRO
#os_ver=`echo $GWMS_OS_VERSION | awk -F'.' '{print $1}'`
#arch=$GWMS_OS_KRNL_ARCH
#dist_file=cvmfsexec-${cvmfs_source}-${os_like}${os_ver}-${arch}
#echo $dist_file

#tar -xvzf $cvmfs_utils_dir/utils/cvmfs_distros.tar.gz -C $cvmfs_utils_dir distros/$dist_file

#. $cvmfs_utils_dir/utils/cvmfs_mount.sh

GWMS_IS_CVMFS=1
glidein_cvmfs="never"
echo $glidein_cvmfs

if [[ $GWMS_IS_CVMFS -eq 0 ]]; then
	# CVMFS is now available on the worker node"
        # mimicking the behavior of the glidein on the worker node (start the user job once the CVMFS repositories are mounted)
	loginfo "Starting user job..."
#        . user_job.sh
else
	if [[ "$glidein_cvmfs" == required ]]; then
		# try to mount CVMFS, if not report an error and exit with failure exit code
		"$error_gen" -error "`basename $0`" "WN_Resource" "Unable to mount required CVMFS on the worker node."
		exit 1
	elif [[ "$glidein_cvmfs" == preferred || "$glidein_cvmfs" == optional ]]; then
		# try to mount CVMFS, if not report a warning/error in the logs and continue with glidein startup
		# script status must be OK, otherwise the glidein will fail
		"$error_gen" -ok "`basename $0`" "WN_Resource" "Unable to mount required CVMFS on the worker node. Continuing without CVMFS."
	elif [[ "$glidein_cvmfs" == never ]]; then
		# do nothing; test the node and print the results but do not even try to mount CVMFS (people do not want it)
		# just continue with glidein startup
		"$error_gen" -ok "`basename $0`" "Not trying to install CVMFS."
	else
		"$error_gen -error "`basename $0`" "WN_Resource" "Invalid factory attribute value specified for CVMFS requirement."
        	exit 1
	fi
			
        #logerror "CVMFS is still unavailable on the worker node"
	#Error occured during mount of CVMFS repositories"
	#exit 1
fi


#. $cvmfs_utils_dir/utils/cvmfs_unmount.sh
