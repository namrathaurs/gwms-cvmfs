#!/bin/bash

usage() {
	echo "This script is used to generate cvmfsexec distributions for all"
	echo "supported machine types (platform- and architecture-based)."
	echo "The script takes one parameter {osg|egi|default} which specifies"
	echo "the source to download the latest cvmfs configuration and repositories."
}

CVMFS_SOURCES=osg:egi:default
SUPPORTED_TYPES=rhel7-x86_64:rhel8-x86_64:suse15-x86_64
cvmfsexec_temp=/tmp/cvmfsexec_pkg
cvmfsexec_base=$cvmfsexec_temp/cvmfsexec
cvmfsexec_distros=$cvmfsexec_temp/distros
cvmfsexec_tarballs=$cvmfsexec_temp/tarballs

if [[ ! -d $cvmfsexec_distros ]]; then
    mkdir -p $cvmfsexec_distros
fi

if [[ ! -d $cvmfsexec_tarballs ]]; then
    mkdir -p $cvmfsexec_tarballs
fi

git clone https://www.github.com/cvmfs/cvmfsexec.git $cvmfsexec_base

declare -a cvmfs_sources
cvmfs_sources=($(echo $CVMFS_SOURCES | tr ":" "\n"))

declare -a machine_types
machine_types=($(echo $SUPPORTED_TYPES | tr ":" "\n"))

for cvmfs_src in "${cvmfs_sources[@]}"
#for cvmfs_src in "osg"
do
    for mach_type in "${machine_types[@]}"
    #for mach_type in "rhel7-x86_64"
    do
        echo -n "Making $cvmfs_src distribution for $mach_type machine..."
        os=`echo $mach_type | awk -F'-' '{print $1}'`
        arch=`echo $mach_type | awk -F'-' '{print $2}'`		
        $cvmfsexec_base/makedist -m $mach_type $cvmfs_src &>/dev/null
        $cvmfsexec_base/makedist -o $cvmfsexec_distros/cvmfsexec-${cvmfs_src}-${os}-${arch} &>/dev/null
        
        if [[ -e $cvmfsexec_distros/cvmfsexec-${cvmfs_src}-${os}-${arch} ]]; then
            echo " Success"
            tar -cvzf $cvmfsexec_tarballs/cvmfsexec_${cvmfs_src}_${os}_${arch}.tar.gz -C $cvmfsexec_distros cvmfsexec-${cvmfs_src}-${os}-${arch} 
            tar -tvzf $cvmfsexec_tarballs/cvmfsexec_${cvmfs_src}_${os}_${arch}.tar.gz             
        else
            echo " Failed!"
        fi
        		
        # delete the dist directory within cvmfsexec to download the cvmfs configuration
        # and repositories for another machine type
        rm -rf $cvmfsexec_base/dist
    done
done
