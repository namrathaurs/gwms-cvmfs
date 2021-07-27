#!/bin/bash

CVMFS_ROOT="/cvmfs"
echo $CVMFS_ROOT

# check for installation of CVMFS...
if [[ `rpm -qa | grep cvmfs` ]]; then
    echo "CVMFS is installed on the node..."
    if [[ -d $CVMFS_ROOT ]]; then
        echo "... and /cvmfs directory exists"
    else
        echo "...but /cvmfs directory does not exist!!"
        # something could be wrong if this happens!!
    fi
else
    echo "CVMFS is not installed on the node."
fi

# validate CVMFS by examining the directories within CVMFS...
config_repo="config-osg.opensciencegrid.org"
# First check...
ls -l $CVMFS_ROOT/$config_repo
if [[ $? -eq 0 ]]; then
    echo "Check #1: CVMFS might be mounted..."
else
    echo "Check #1: CVMFS might not be accessible"
fi

# Second check...
if [[ -f $CVMFS_ROOT/$config_repo/.cvmfsdirtab || "$(ls -A $CVMFS_ROOT/$config_repo)" ]]; then
    echo "Check #2: CVMFS might be mounted..."
else
    echo "Check #2: Repository directory is empty or does not have .cvmfsdirtab"
fi

# Third check...
findmnt -t fuse -S cvmfs2 -O user_id=0,group_id=0
if [[ $? -eq 0 ]]; then
    echo "Check #3: CVMFS is mounted already by an admin."
else
    echo "Check #3: CVMFS is not mounted!!"
fi

mnts=`findmnt -t fuse -S cvmfs2 -O user_id=0,group_id=0`
echo $mnts


###################################################################

#[ "$(ls -A /cvmfs)" ] && echo "Not Empty" || echo "Empty"
#if [[ -d /cvmfs/$config_repo ]] ; then
#    echo "cvmfs repo directory exists"
#else
#    echo " cvmfs repo directory does not exists"
#fi

#if [[ -f /cvmfs/$config_repo/.cvmfsdirtab ]]; then
#    echo "CVMFS is installed on the system"
#else
#    echo "CVMFS is not installed"
#fi
#
#ls -l /cvmfs/$config_repo
#echo $?

#mnt_src="cvmfs2"
#sys_mounts=`findmnt $mnt_src | awk '{print $2}' | wc -l`
#echo $sys_mounts
