#!/bin/bash
echo  "Executing user job..."
/bin/hostname
echo ""
echo $GLIDEIN_CVMFS_CONFIG_REPO
echo $GLIDEIN_CVMFS_REPOS
echo ""
ls -l $cvmfs_utils_dir/.cvmfsexec/dist/cvmfs/singularity.opensciencegrid.org
