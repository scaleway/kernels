#! /bin/bash

action=$1
shift

test_start() {
    bootscript=$1
    commercial_type=$2
    test_image=$3

    scw login -o "$SCW_ORGANIZATION" -t "$SCW_TOKEN" -s 1>&2
    scw run -d --commercial-type="$commercial_type" --bootscript="$bootscript" "$test_image"
}

test_stop() {
    server=$1

    scw rm -f $server
}

test_$action "$@"
