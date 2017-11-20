#! /bin/bash

action=$1
shift

_scw() {
    output=$(scw "$@" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error, Scaleway CLI returned:" >&2
        echo "$output" >&2
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
        time_begin=$(date +%s)
        boot_timeout=600
        while true; do
            time_elapsed=$(echo "$(date +%s)-$time_begin" | bc)
            if [ $time_elapsed -gt $boot_timeout ]; then
                echo "Could not boot server" >&2
                exit 2
            else
                server_info=$(get_server $server_id)
                server_state=$(echo $server_info | jq -r '.server.state')
                if [ "$server_state" = "stopped" ]; then
                    _scw start $server_id
                elif [ "$server_state" = "starting" ]; then
                    sleep 30
                elif [ "$server_state" = "running" ]; then
                    break
                else
                    continue
                fi
            fi
            sleep 1
        done
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

    grep -v "^$" $server_id_file | while read server_type server_name server_id; do
        echo "Removing $server_type server $server_name..."
        maximum_rm_tries=3
        try=0
        while (get_server $server_id | jq -r '.server.state' | grep -qxE 'running'); do
            _scw stop -t $server_id
            sleep 1
            if [ $try -gt $maximum_rm_tries ]; then
                echo "Could not stop server $server_name properly"
                break
            fi
            ((try += 1))
        done
    done
}

test_$action "$@"
