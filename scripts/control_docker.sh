#!/usr/bin/env bash
cd $HOME/projects/neverlight-home-automation
./scripts/check_docker.sh
rv=$?
echo "Sort out $rv"

if [ $rv == 0 ];then
    notify-send -a docker "Stopping the mini-stack"
    docker compose stop
else
    notify-send -a docker "Starting the mini-stack"
    docker compose up -d
    notify-send "Docker images starting..."
fi
