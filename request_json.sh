#! /bin/bash

branch=$1
arch=$2
if [ "$3" = 'release' ]; then
    is_test=false
else
    is_test=true
fi


urlencode() {
    echo $(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' $1)
}

enc_branch=$(urlencode $branch)
encenc_branch=$(urlencode $enc_branch)

release_path="/job/kernel-build/job/$encenc_branch/lastSuccessfulBuild/artifact/$arch/release"

jq -n --arg t $is_test --arg p "$release_path" --arg a "$arch" --arg b "$branch" \
    '{ type: "bootscript", options: { test: ($t == "true") }, data: { release_path: $p, arch: $a, branch: $b } }'
