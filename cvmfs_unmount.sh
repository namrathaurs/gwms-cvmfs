#!/bin/bash
echo "Inside cvmfs_unmount.sh"

df -h | grep /cvmfs &> /dev/null
IS_CVMFS_MOUNT=$?

if [[ $IS_CVMFS_MOUNT -eq 0 ]]; then
	cvmfsexec/cvmfsexec/umountrepo -a
	echo "CVMFS repositories unmounted"

else
	echo "CVMFS repositories are not mounted"
fi

df -h
