#!/bin/bash
echo  "Executing user job..."
/bin/hostname
echo ""
echo $cvmfs_utils_dir
echo ""
ls -l $cvmfs_utils_dir/.cvmfsexec/dist/cvmfs/singularity.opensciencegrid.org
