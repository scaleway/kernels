#! /bin/bash

action=$1
shift

_scw() {
    output=$(scw "$@" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error, Scaleway CLI returned:\n$output" >&2
    fi
}

_ssh() {
    ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -i ~/.ssh/id_builder "$@"
}

get_server() {
    res=$(curl --fail -s https://api.scaleway.com/servers/$1 -H "x-auth-token: $SCW_TOKEN")
    if [ $? -ne 0 ]; then
        echo "Error, Scaleway API returned:\n$res" >&2
        return 1
    else
        echo $res
    fi
}

get_image() {
    curl --fail -s https://api-marketplace.scaleway.com/images | jq -r --arg arch "$1" --arg img "$2" '.images[] | select(.name | test($img; "i")).versions[0].local_images[] | select(.arch == $arch and .zone == "par1").id'
}

test_start() {
    arch=$1
    buildbranch=$2
    IFS='/' read flavor version <<< $buildbranch
    bootscript=$3
    server_id_file=$4

    if [ "$flavor" = "mainline" ]; then
        image_name="ubuntu xenial"
    else
        image_name="$flavor $version"
    fi
    test_image=$(get_image $arch "$image_name")
    if [ -z "$test_image" ]; then
        echo "No image found for this kernel."
        exit 1
    fi

    _scw login -o "$SCW_ORGANIZATION" -t "$SCW_TOKEN" -s
    key=$(cat ~/.ssh/id_builder.pub | cut -d' ' -f1,2 | tr ' ' '_')

    server_types=$(grep -E "$arch\>" server_types | cut -d'|' -f2 | tr ',' ' ')
    : > $server_id_file

    for server_type in $server_types; do
        server_name="kernel-test-$(uuidgen -r)"

        # Try to create the server
        echo "Creating $server_type server $server_name..."
        maximum_create_tries=5
        for try in `seq 1 $maximum_create_tries`; do
            _scw create --ip-address="none" --commercial-type="$server_type" --bootscript="$bootscript" --name="$server_name" --env="AUTHORIZED_KEY=$key" "$test_image"
            sleep 1
            if [ $(scw ps -a -q --filter="name=$server_name" | wc -l) -gt 0 ]; then
                break
            fi
            backoff=$(echo "(2^($try-1))*60" | bc)
            sleep $backoff
        done
        if ! [ $(scw ps -a -q --filter="name=$server_name" | wc -l) -gt 0 ]; then
            echo "Could not create server"
            exit 1
        fi
        server_id=$(scw ps -a -q --filter="name=$server_name")
        echo "Created server $server_name, id: $server_id"
        echo "$server_type $server_name $server_id" >> $server_id_file

        # Try to boot the server
        echo "Booting server $server_name..."
        maximum_boot_tries=3
        boot_timeout=600
        for try in `seq 1 $maximum_boot_tries`; do
            if (get_server $server_id | jq -r '.server.state' | grep -qxE 'stopped'); then
                _scw start $server_id
            fi
            sleep 1
            if (get_server $server_id | jq -r '.server.state' | grep -qxE 'starting'); then
                echo "Server is starting."
                time_begin=$(date +%s)
                while (get_server $server_id | jq -r '.server.state' | grep -qxE 'starting') ; do
                    time_now=$(date +%s)
                    time_diff=$(echo "$time_now-$time_begin" | bc)
                    if [ $time_diff -gt $boot_timeout ]; then
                        echo "Waited $boot_timeout seconds for server to boot, aborting." >&2
                        break
                    fi
                    sleep 5
                done
            fi
            sleep 1
            if (get_server $server_id | jq -r '.server.state' | grep -qxE 'running'); then
                echo "Server has been started."
                break
            fi
            backoff=$(echo "($try-1)*60" | bc)
            echo "Retrying after backoff $backoff seconds." >&2
            sleep $backoff
        done
        if ! (get_server $server_id | jq -r '.server.state' | grep -qxE 'running'); then
            echo "Could not boot server"
            exit 2
        fi
        echo "Server $server_name booted"
        server_ip=$(get_server $server_id | jq -r '.server.private_ip')

        # Wait for ssh
        echo "Waiting for ssh to be available on server $server_name..."
        ssh_up_timeout=300
        time_begin=$(date +%s)
        while ! nc -zv $server_ip 22 >/dev/null 2>&1; do
            time_now=$(date +%s)
            time_diff=$(echo "$time_now-$time_begin" | bc)
            if [ $time_diff -gt $ssh_up_timeout ]; then
                echo "Failed testing server, could not detect a listening sshd"
                exit 3
            fi
            sleep 1
        done

        # Do some simple tests on the server
        echo "Testing kernel on server $server_name..."
        if ! _ssh root@$server_ip uname -a; then
            echo "Failed testing server, could not execute remote command"
            exit 3
        fi
        echo "Done testing server $server_name with success"
    done
}

test_stop() {
    server_id_file=$1

    _scw login -o "$SCW_ORGANIZATION" -t "$SCW_TOKEN" -s

    failed=false
    grep -v "^$" $server_id_file | while read server_type server_name server_id; do
        echo "Removing $server_type server $server_name..."
        maximum_rm_tries=3
        for try in `seq 1 $maximum_rm_tries`; do
            if (get_server $server_id | jq -r '.server.state' | grep -qxE 'running'); then
                _scw stop -t $server_id
            fi
            sleep 1
            if (get_server $server_id | jq -r '.server.state' | grep -qxE 'stopping'); then
                _scw wait $server_id
            fi
            sleep 1
            if (get_server $server_id | jq -r '.server.state' | grep -qxE 'stopped'); then
                _scw rm $server_id
            fi
            if ! (get_server $server_id); then
                break
            fi
            backoff=$(echo "($try-1)*60" | bc)
            sleep $backoff
        done
        if (get_server $server_id); then
            echo "Could not stop and remove server $server_name"
            failed=true
        else
            echo "Server $server_name removed"
        fi
    done
    if $failed; then exit 1; fi
}

test_$action "$@"
