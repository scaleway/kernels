#! /bin/bash

KERNEL_DIR=$1

./patches/patch_aufs.sh $KERNEL_DIR 4.11.7+
