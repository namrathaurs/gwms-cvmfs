#!/bin/bash

echo $1
echo $#
# first parameter passed to this script will always be the glidein configuration file (glidein_config)
glidein_config=$1

# fetch the error reporting helper script
error_gen=`grep '^ERROR_GEN_PATH ' $glidein_config | awk '{print $2}'`
#echo $error_gen

# get the glidein work directory location from glidein_config file
work_dir=`grep '^GLIDEIN_WORK_DIR ' $glidein_config | awk '{print $2}'`
#echo "Glidein Work Directory: $work_dir"

# get the CVMFS source information from <attr> in the glidein configuration 
#cvmfs_source=osg
cvmfs_source=`grep '^CVMFS_SRC ' $glidein_config | awk '{print $2}'`
#echo "CVMFS Source: $cvmfs_source"

# get the CVMFS requirement setting passed as one of the factory attributes
glidein_cvmfs=`grep '^GLIDEIN_CVMFS ' $glidein_config | awk '{print $2}'`
#echo $glidein_cvmfs

# store the directory location, to where the tarball is unpacked by the glidein, to a variable
#cvmfs_utils_dir=/home/testuser/gwms-cvmfs/cvmfs_utils
cvmfs_utils_dir=$work_dir/cvmfs_utils
#echo "Glidein cvmfs_utils_dir: $cvmfs_utils_dir"

# $PWD=/tmp/glide_xxx and every path is referenced with respect to $PWD
# source the helper script
source $cvmfs_utils_dir/utils/cvmfs_helper_funcs.sh

perform_system_check

os_like=$GWMS_OS_DISTRO
os_ver=`echo $GWMS_OS_VERSION | awk -F'.' '{print $1}'`
arch=$GWMS_OS_KRNL_ARCH
dist_file=cvmfsexec-${cvmfs_source}-${os_like}${os_ver}-${arch}
#echo $dist_file

#tar -tvzf $cvmfs_utils_dir/utils/cvmfs_distros.tar.gz
tar -xvzf $cvmfs_utils_dir/utils/cvmfs_distros.tar.gz -C $cvmfs_utils_dir distros/$dist_file

. $cvmfs_utils_dir/utils/cvmfs_mount.sh

if [[ $GWMS_IS_CVMFS -eq 0 ]]; then
	# CVMFS is now available on the worker node"
        # mimicking the behavior of the glidein on the worker node (start the user job once the CVMFS repositories are mounted)
	loginfo "Starting user job..."
#        . user_job.sh
else
        logerror "CVMFS is still unavailable on the worker node"
	#Error occured during mount of CVMFS repositories"
	exit 1
fi


#. $cvmfs_utils_dir/utils/cvmfs_unmount.sh
