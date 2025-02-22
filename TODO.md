# Remaining work.


    * The docker compose stack:

    wire up webcam more permanently on linux box

    * Notes

    After looking at the AUR stuff I think I really, really want this to all be a docker-compose file.
    Its easier to share, will break less stuff and wont fuck with the system python.

    https://companion.home-assistant.io/

    https://github.com/rhasspy/wyoming-satellite

    I cant find docker images for 
    https://github.com/rhasspy/wyoming-satellite.git

## Fork all the things?

Build everything manually? The images all want to use alsa stuff. I'm using pipewire and i'm not going back.
That said, the dockerfiles are pretty straight forward.

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

Getting pipewire to work was fun. The default images all use ancient alsa stuff.
Set some env vars and share the running socket. It works but I can't figure out how to get HA to talk to it.
I also had to tweak the Dockerfiles of the wyoming containers to use pipewire instead of alsa. One thing at a time.

If I can't get it to send audio to a remote socket, then this is likely going to get simplified WRT the compose file.

```
docker run --rm -it -e DISABLE_RTKIT=y -e XDG_RUNTIME_DIR=/tmp -e PIPEWIRE_RUNTIME_DIR=/tmp -e PULSE_RUNTIME_DIR=/tmp -v /dev/snd:/dev/snd -v /var/run/user/1000/pipewire-0:/tmp/pipewire-0 -v $PWD:/work --entrypoint bash satellite:latest
```

### Home Assistant Green

Bought an appliance to just run HA and wyoming protocol on. Attached a cheap usb mic.
Got voice recognition working and using an ollama llm for the conversation agent.

However, I can trigger it and debug see it's doing all the steps including generating an audio file response.

But no playback. I think I need to snag a cheap USB speaker as it looks like the sound output is expecting to play locally.

However, the green has NO built in audio. This kind of doesn't make sense. I really wanted to route sound output via the wyoming protocol, but I don't undertand it enough to even know if that's possible.

So, things are on hold a bit while I get sound output to a local speaker working.

### LobeChat

File upload/RAG/knowlege management


### Ollama

Fix/update as approprate and tell emacs about it.

pulling llama3:8b-instruct-q8_0
pulling 11a9680b0168... 100% ▕████████████████▏ 8.5 GB                         

pulling llama3:8b-instruct-q8_0
pulling 11a9680b0168... 100% ▕████████████████▏ 8.5 GB                         

pulling mistral:7b-instruct-v0.2-q6_K
pulling 3678b2e574ad... 100% ▕████████████████▏ 5.9 GB                         

-- seems like this is from nvidia and not hugging face
pulling mixtral:8x7b-instruct-v0.1-q3_K_M-4k
Error: pull model manifest: file does not exist

pulling qwen2.5:3b
pulling 5ee4f07cdb9b... 100% ▕████████████████▏ 1.9 GB                         

pulling qwen2.5:3b
pulling 5ee4f07cdb9b... 100% ▕████████████████▏ 1.9 GB                         

pulling qwen2.5-coder:3b
pulling 4a188102020e... 100% ▕████████████████▏ 1.9 GB                         

pulling qwen2.5-coder:7b-instruct-q8_0
pulling 24b532e52765... 100% ▕████████████████▏ 8.1 GB                         

pulling zephyr:7b-beta-q6_K
pulling bd76fa39fe71... 100% ▕████████████████▏ 5.9 GB                         
