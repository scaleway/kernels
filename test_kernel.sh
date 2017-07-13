#! /bin/bash

action=$1
shift

_scw() {
    scw "$@" >/dev/null 2>&1
}

_ssh() {
    ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -i ~/.ssh/id_builder "$@"
}

get_server() {
    res=$(curl --fail -s https://api.scaleway.com/servers/$1 -H "x-auth-token: $2")
    if [ $? -ne 0 ]; then
        return 1
    else
        echo $res
    fi
}

test_start() {
    bootscript=$1
    commercial_type=$2
    test_image=$3
    server_id_file=$4

    server_name="kernel-test-$(uuidgen -r)"
    key=$(cat ~/.ssh/id_builder.pub | cut -d' ' -f1,2 | tr ' ' '_')

    _scw login -o "$SCW_ORGANIZATION" -t "$SCW_TOKEN" -s

    # Try to create the server
    echo "Creating server..."
    maximum_create_tries=5
    for try in `seq 1 $maximum_create_tries`; do
        _scw create --commercial-type="$commercial_type" --bootscript="$bootscript" --name="$server_name" --env="AUTHORIZED_KEY=$key" "$test_image"
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
    echo $server_id >$server_id_file

    # Try to boot the server
    echo "Booting server..."
    maximum_boot_tries=3
    boot_timeout=600
    for try in `seq 1 $maximum_boot_tries`; do
        if (get_server $server_id $SCW_TOKEN | jq -r '.server.state' | grep -qxE 'stopped'); then
            _scw start $server_id
        fi
        sleep 1
        if (get_server $server_id $SCW_TOKEN | jq -r '.server.state' | grep -qxE 'starting'); then
            time_begin=$(date +%s)
            while (get_server $server_id $SCW_TOKEN | jq -r '.server.state' | grep -qxE 'starting') ; do
                time_now=$(date +%s)
                time_diff=$(echo "$time_now-$time_begin" | bc)
                if [ $time_diff -gt $boot_timeout ]; then
                    break
                fi
                sleep 5
            done
        fi
        sleep 1
        if (get_server $server_id $SCW_TOKEN | jq -r '.server.state' | grep -qxE 'running'); then
            break
        fi
        backoff=$(echo "($try-1)*60" | bc)
        sleep $backoff
    done
    if ! (get_server $server_id $SCW_TOKEN | jq -r '.server.state' | grep -qxE 'running'); then
        echo "Could not boot server"
        exit 2
    fi
    echo "Server booted"
    server_ip=$(get_server $server_id $SCW_TOKEN | jq -r '.server.public_ip.address')

    # Wait for ssh
    echo "Waiting for ssh to be available..."
    ssh_up_timeout=300
    time_begin=$(date +%s)
    while ! nc -zv $server_ip 22 >/dev/null 2>&1; do
        time_now=$(date +%s)
        time_diff=$(echo "$time_now-$time_begin" | bc)
        if [ $time_diff -gt $ssh_up_timeout ]; then
            exit 3
        fi
        sleep 1
    done

    # Do some simple tests on the server
    echo "Testing kernel on server $server_name..."
    if ! _ssh root@$server_ip uname -a; then
        exit 3
    fi
    echo "Done"
}

test_stop() {
    server_id=$1

    _scw login -o "$SCW_ORGANIZATION" -t "$SCW_TOKEN" -s

    echo "Removing server..."
    maximum_rm_tries=3
    for try in `seq 1 $maximum_rm_tries`; do
        if (get_server $server_id $SCW_TOKEN | jq -r '.server.state' | grep -qxE 'running'); then
            _scw stop -t $server_id
        fi
        sleep 1
        if (get_server $server_id $SCW_TOKEN | jq -r '.server.state' | grep -qxE 'stopping'); then
            _scw wait $server_id
        fi
        sleep 1
        if (get_server $server_id $SCW_TOKEN | jq -r '.server.state' | grep -qxE 'stopped'); then
            _scw rm $server_id
        fi
        if ! (get_server $server_id $SCW_TOKEN); then
            break
        fi
        backoff=$(echo "($try-1)*60" | bc)
        sleep $backoff
    done
    if (get_server $server_id $SCW_TOKEN); then
        echo "Could not stop and remove server"
        exit 1
    fi
    echo "Server removed"
}

test_$action "$@"
