#!/usr/bin/env zsh
# This lets me play sounds via pipewire from within docker
docker run --rm -it    -e DISABLE_RTKIT=y -e XDG_RUNTIME_DIR=/tmp -e PIPEWIRE_RUNTIME_DIR=/tmp -e PULSE_RUNTIME_DIR=/tmp -v /dev/snd:/dev/snd -v /var/run/user/1000/pipewire-0:/tmp/pipewire-0 -v $PWD:/work --entrypoint bash satellite:latest
