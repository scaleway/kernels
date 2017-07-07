#!/bin/bash

###################################################
## Patch the Linux source tree with AUFS support ##
###################################################

set -e

KERNEL_SRC_DIR=$1
KVER=$2

# Temporary Location
GIT=`mktemp -d`
GIT_URL=git://github.com/sfjro/aufs4-standalone.git
BINPREFIX=aufs4-

# Clone AUFS repo
git clone --branch aufs$KVER $GIT_URL $GIT

# Temporary patch patch
patch -d $GIT -p1 < patches/aufs_patch_patch.patch

# Copy in files
cp -r $GIT/{Documentation,fs} $KERNEL_SRC_DIR
cp $GIT/include/uapi/linux/aufs_type.h $KERNEL_SRC_DIR/include/uapi/linux/aufs_type.h

# Apply patches
cat $GIT/${BINPREFIX}{base,kbuild,loopback,mmap,standalone}.patch | patch -d $KERNEL_SRC_DIR -p1

# Clean Up
rm -rf $GIT

echo "Patched kernel with AUFS support!"
