#!/bin/bash

usage() {
	echo "This script is used to generate cvmfsexec distributions for all"
	echo "supported machine types (platform- and architecture-based)."
	echo "The script takes one parameter {osg|egi|default} which specifies"
	echo "the source to download the latest cvmfs configuration and repositories."
}

# parameter is 'osg', 'egi' or 'default' to download the latest cvmfs and configuration
# rpm from one of those three sources (Ref. https://www.github.com/cvmfs/cvmfsexec)
#cvmfs_src=$1
# uncomment the following if block if the source is passed as a command line argument
#if [[ ! $cvmfs_src =~ ^(osg|egi|default)$ ]]; then
#	echo "Invalid command line argument: Must be one of {osg|egi|default}"
#	exit 1
#fi

CVMFS_SOURCES=osg:egi
SUPPORTED_TYPES=rhel6-x86_64:rhel7-x86_64:rhel8-x86_64:suse15-x86_64
cvmfsexec_temp=/tmp/cvmfsexec_pkg
cvmfsexec_base=$cvmfsexec_temp/cvmfsexec
cvmfs_distros=$cvmfsexec_temp/distros

if [[ ! -d $cvmfsexec_temp ]]; then
	mkdir -p $cvmfsexec_temp
	mkdir -p $cvmfs_distros
elif [[ -d $cvmfsexec_temp && ! -d $cvmfs_distros ]]; then
	mkdir -p $cvmfs_distros
fi

if [[ ! -d $cvmfsexec_base ]]; then
	git clone https://www.github.com/cvmfs/cvmfsexec.git $cvmfsexec_base &> $cvmfsexec_temp/gen_distros.log 
elif [[ -d $cvmfsexec_base && -d $cvmfsexec_base/dist ]]; then
	rm -rf $cvmfsexec_base/dist	
fi
#echo $?

declare -a repo_sources
repo_sources=($(echo $CVMFS_SOURCES | tr ":" "\n"))

declare -a avail_types
avail_types=($(echo $SUPPORTED_TYPES | tr ":" "\n"))
#echo ${avail_types[@]}       


for cvmfs_src in "${repo_sources[@]}"
do
	for avail_type in "${avail_types[@]}"
	do
		echo -n "Making $cvmfs_src distribution for $avail_type machine..."
		os=`echo $avail_type | awk -F'-' '{print $1}'`
		arch=`echo $avail_type | awk -F'-' '{print $2}'`		
		$cvmfsexec_base/makedist -m $avail_type $cvmfs_src &>> $cvmfsexec_temp/gen_distros.log 
		$cvmfsexec_base/makedist -o $cvmfs_distros/cvmfsexec-${cvmfs_src}-${os}-${arch} &>> $cvmfsexec_temp/gen_distros.log
		
		if [[ -e $cvmfs_distros/cvmfsexec-${cvmfs_src}-${os}-${arch} ]]; then
			echo " Success"
		else
			echo " Failed! Check $cvmfsexec_temp/gen_distros.log for details."
		fi
			
		# delete the dist directory within cvmfsexec to download the cvmfs configuration
		# and repositories for another machine type
		rm -rf $cvmfsexec_base/dist
	done
done

echo -e "\nCreating a tarball with generated distributions for all supported machine types..."
tar -cvzf $cvmfsexec_temp/cvmfs_distros.tar.gz -C $cvmfsexec_temp distros &>> $cvmfsexec_temp/gen_distros.log

# check if the tarball has all the distros previously created!
tar -tvzf $cvmfsexec_temp/cvmfs_distros.tar.gz

echo "Tarball containing cvmfsexec distributions is now available in $cvmfsexec_temp"
