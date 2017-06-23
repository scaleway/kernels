#! /bin/bash

branch=$1
buildno=$2
arch=$3

urlencode() {
    echo $(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' $1)
}

kernel_flavor=${branch%%/*}
enc_branch=$(urlencode $branch)
encenc_branch=$(urlencode $enc_branch)

build_path="/job/kernel-build/job/$encenc_branch/$buildno"
artifacts_url="${JENKINS_URL}${build_path}/artifact/"
kernel_version=$(curl -s $artifacts_url/$arch/release/version)
if [ "$arch" = 'arm' -o "$arch" = 'x86_64' ]; then
    image_type='vmlinuz'
elif [ "$arch" = 'arm64' ]; then
    image_type='vmlinux'
fi
kernel_name="${image_type}-${kernel_version}"

jq -n --arg kf "$kernel_flavor" --arg kv "$kernel_version" --arg kn "$kernel_name" --arg bp "$build_path" --arg a "$arch" \
    '{ kernel_flavor: $kf, kernel_version: $kv, kernel_name: $kn, build_path: $bp, arch: $a }'
