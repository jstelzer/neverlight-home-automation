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


### Remote Audio idea

** Ellama:
Here's a high-level guide on how to set up GStreamer and PipWire to
stream audio from Home Assistant to your remote sound server using
Docker Compose:

*Docker Compose Setup*

Create a new ~docker-compose.yml~ file with the following
configuration:
#+BEGIN_SRC yaml
version: '3'

services:
  home-assistant:
    image: homeassistant/home-assistant
    volumes:
      - ./config.yaml:/etc/homeassistant/config.yaml
      - ./media:/var/lib/home-assistant/media
    ports:
      - "8125:8125"
      - "5050:5050"

  gstreamer:
    image: linuxfoundation/gstreamer
    volumes:
      - ./gstreamer.conf:/etc/gstreamer/conf.d/gstreamer.conf
    depends_on:
      - home-assistant

  pipewire:
    image: alpine/pipewire
    volumes:
      - ./pipewire.conf:/etc/pipewire/pipewire.conf
    depends_on:
      - gstreamer
#+END_SRC
*GStreamer Configuration*

Create a new file ~gstreamer.conf~ with the following content:
#+BEGIN_SRC ini
[main]
enable-echo = true

[elements source]
type = audiofilesrc
location = /path/to/audio/file.wav
format = wav/24Stereo
blocksize = 2048

[elements sink]
type = alsa-sink
access=media.stream
device="hw:0,0"
channel-order=(int16)(int16)
#+END_SRC
This configuration tells GStreamer to:

1. Use an audio file (~/path/to/audio/file.wav~) as the input source.
2. Set the audio format to WAV with 24-bit stereo.
3. Stream the audio using ALSA.

*PipWire Configuration*

Create a new file ~pipewire.conf~ with the following content:
#+BEGIN_SRC ini
[global]
enable-echo = true

[elements sink]
type = alsa-sink
access=media.stream
device="hw:0,0"
channel-order=(int16)(int16)

[pulse]
default-client = 1
#+END_SRC
This configuration tells PipWire to:

1. Enable echo.
2. Use ALSA as the output device (~hw:0,0~).
3. Configure the default client to use ALSA.

*Home Assistant Integration*

In your ~home-assistant/config.yaml~ file, add the following
configuration:
#+BEGIN_SRC yaml
audio:
  - platform: gstreamer
    name: remote_audio
    stream_url: rtsp://remote_sound_server_ip:5050
#+END_SRC
This configuration tells Home Assistant to:

1. Use GStreamer as the audio platform.
2. Set up a streaming URL (~rtsp://~) pointing to your remote sound
server.

*Streaming Audio*

When you want to play an audio response from Home Assistant, use the
~play_audio~ command in your Home Assistant config file (e.g.,
~config.yaml~). For example:
#+BEGIN_SRC yaml
audio:
  - platform: media_player
    name: remote_audio
#+END_SRC
This will stream the audio to your remote sound server.

*Notes*

+ Make sure your remote sound server is running and configured
correctly.
+ You may need to adjust the GStreamer configuration to match your
specific audio requirements.
+ This setup assumes a basic audio streaming scenario; you can add
more features, such as volume control or mute functionality, by
extending this configuration.
