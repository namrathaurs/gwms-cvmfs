#!/bin/bash

# first parameter passed to this script will always be the glidein configuration file (glidein_config)
glidein_config=$1

# fetch the error reporting helper script
#error_gen=`grep '^ERROR_GEN_PATH ' $glidein_config | awk '{print $2}'`
#echo $error_gen
# Everything worked out fine
#"$error_gen" -ok <script name> [<key> <value>]*
# Uh oh, we hit an error
#"$error_gen" -error <script name> <error type> "<detailed description>" [<key> <value>]*

# get the glidein work directory location from glidein_config file
#work_dir=`grep '^GLIDEIN_WORK_DIR ' $glidein_config | awk '{print $2}'`
#echo "Glidein Work Directory: $work_dir"
work_dir=$HOME/gwms-cvmfs

# fetch the ENABLE_CVMFS attribute from the glidein configuration file
#enable_cvmfs=`grep '^ENABLE_CVMFS ' $glidein_config | awk '{print $2}'`
#echo "ENABLE_CVMFS=$enable_cvmfs"

# store the directory location, to where the tarball is unpacked by the glidein, to a variable
cvmfs_utils_dir=$work_dir/cvmfs_utils

# $PWD=/tmp/glide_xxx and every path is referenced with respect to $PWD
# source the helper script
source $cvmfs_utils_dir/cvmfs_helper_funcs.sh

. $cvmfs_utils_dir/cvmfs_mount.sh

if [[ $GWMS_IS_CVMFS -eq 0 ]]; then
	# CVMFS is now available on the worker node"
        # mimicking the behavior of the glidein on the worker node (start the user job once the CVMFS repositories are mounted)
	loginfo "Starting user job..."
        . user_job.sh
else
        logerror "CVMFS is still unavailable on the worker node"
	#Error occured during mount of CVMFS repositories"
	exit 1
fi


. $cvmfs_utils_dir/cvmfs_unmount.sh

###################################################################################################################################################

# fetch the ENABLE_CVMFS attribute from the glidein configuration file
#enable_cvmfs=`grep '^ENABLE_CVMFS ' $glidein_config | awk '{print $2}'`
#echo "ENABLE_CVMFS=$enable_cvmfs"

# import add_config_line function
#add_config_line_source=`grep '^ADD_CONFIG_LINE_SOURCE ' $glidein_config | awk '{print $2}'`
#source $add_config_line_source
# add an attributes
#add_config_line ENABLE_CVMFS 1

# untar the necessary utilities to the tmp directory under the glidein work dir (using the -C option; can also use --directory option for the same)
#if [ -e $work_dir/cvmfs_utils.tar.gz ]; then
#	echo "Inside if..."
#	tar -xvzf $work_dir/cvmfs_utils.tar.gz -C $tmp_dir
#else
#	"$error_gen" -error "cvmfs_test.sh" "WN_Resource" "Could not find cvmfs_test.sh" "file" "$work_dir/cvmfs_utils.tar.gz" "base_dir_attr" "$work_dir"
#fi
#./mycvmfsexec -- ls -al
#readlink -f $0
#.cvmfsexec/mountrepo cvmfs-config.cern.ch
