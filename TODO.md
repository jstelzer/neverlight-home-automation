# Remaining work.

* See https://academy.networkchuck.com/blog/local-ai-voice-assistant

* The docker compose stack:

wire up webcam more permanently on linux box

home-assistant (share the tcp socket globally)

wyoming-satalite protocol

ollama (enable gpu)

iphone (get app working)


* Notes

After looking at the AUR stuff I think I really, really want this to all be a docker-compose file.
Its easier to share, will break less stuff and wont fuck with the system python.

https://walkergriggs.com/2022/12/03/pipewire_in_docker/

https://stackoverflow.com/questions/70761192/docker-compose-equivalent-of-docker-run-gpu-all-option

https://companion.home-assistant.io/

https://wiki.archlinux.org/title/Home_Assistant

https://github.com/rhasspy/wyoming-satellite

I cant find docker images for 
https://github.com/rhasspy/wyoming-satellite.git

Build everything manually?

```
7354  git clone https://github.com/rhasspy/wyoming-satellite.git
7355  cd wyoming-satellite
7361  docker build -t wyoming-satellite:latest .
7362  cd ../
7363  git clone https://github.com/rhasspy/wyoming-snd-external.git
7364  cd wyoming-snd-external
7365  ls
7366  docker build -t wyoming-snd-external:latest .
7367  cd ..
7368  git clone https://github.com/rhasspy/wyoming-mic-external.git
7369  cd wyoming-mic-external
7370  docker build -t wyoming-mic-external:latest .
```
