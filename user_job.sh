#!/bin/bash
echo "Executing user job..."

dirname=`dirname $(readlink -f $0)`
ls -l $dirname/cvmfsexec/dist/cvmfs/singularity.opensciencegrid.org
