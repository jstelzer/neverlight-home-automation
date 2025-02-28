#!/usr/bin/env bash

PATH=$PATH:/home/mental/.cargo/bin
WORK_DIR=${HOME}/projects/neverlight-home-automation
cd $WORK_DIR
STATUS=""
function set_status {
    STATUS=$(docker compose ls --format json|jq -r '.[0].Status');
}

set_status

if [ -z ${STATUS} ] ; then
    notify-send -a docker "Stack stopped."
    exit 1
fi

if [ $(echo $STATUS|rg running) ]; then
    notify-send -a docker "Stack running"
    exit 0
fi

notify-send -a docker "Stack stopped"
exit 1

