#!/bin/bash

usage() {
	echo "This script is used to generate cvmfsexec distributions for all"
	echo "supported machine types (platform- and architecture-based)."
	echo "The script takes one parameter {osg|egi|default} which specifies"
	echo "the source to download the latest cvmfs configuration and repositories."
}


# parameter is 'osg', 'egi' or 'default' to download the latest cvmfs and configuration
# rpm from one of those three sources (Ref. https://www.github.com/cvmfs/cvmfsexec)
cvmfs_src=$1
cvmfsexec_temp=/tmp/cvmfsexec_pkg
cvmfsexec_base=$cvmfsexec_temp/cvmfsexec
if [[ ! $cvmfs_src =~ ^(osg|egi|default)$ ]]; then
	echo "Invalid command line argument: Must be one of {osg|egi|default}"
	exit 1
fi

if [[ ! -d $cvmfsexec_base ]]; then
	git clone https://www.github.com/cvmfs/cvmfsexec.git $cvmfsexec_base
elif [[ -d $cvmfsexec_base && -d $cvmfsexec_base/dist ]]; then
	rm -rf $cvmfsexec_base/dist	
fi
#echo $?

supported_types=rhel6-x86_64:rhel7-x86_64:rhel8-x86_64:suse15-x86_64
declare -a avail_types
avail_types=($(echo $supported_types | tr ":" "\n"))
echo ${avail_types[@]}       

for type in "${avail_types[@]}"
do
	os=`echo $type | awk -F'-' '{print $1}'`
	arch=`echo $type | awk -F'-' '{print $2}'`		
	$cvmfsexec_base/makedist -m $type $cvmfs_src
	$cvmfsexec_base/makedist -o $cvmfsexec_temp/cvmfsexec-${cvmfs_src}-${os}-${arch}

	# delete the dist directory within cvmfsexec to download the cvmfs configuration
	# and repositories for another machine type
	rm -rf $cvmfsexec_base/dist
done

echo "cvmfsexec distributions are available in $cvmfsexec_temp"
