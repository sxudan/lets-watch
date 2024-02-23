# lets-watch

Lets-watch is a Flutter project that brings people together to watch videos in real-time using the RTMP protocol. This application leverages the power of Flutter for a cross-platform experience, allowing users to seamlessly watch and enjoy videos simultaneously.

## Features
- **Real-Time Video Streaming:** Watch videos together with friends in real-time using the robust RTMP protocol.
- **Cross-Platform:** Built with Flutter, the app is designed to run smoothly on both iOS and Android devices.
- **Seamless Experience:** Enjoy a seamless and synchronized watching experience with friends, no matter where they are.

## How it Works
Lets-watch utilizes the Flutter framework for the user interface and implements the RTMP protocol for real-time video streaming. The power of FFmpeg is harnessed to handle video processing, ensuring a smooth and efficient watching experience.


# How to run 

## Setup media server

I recommend this docker image - 
```
https://github.com/bluenviron/mediamtx?tab=readme-ov-file#docker-image
```

## Clone the project

```
git clone https://github.com/sxudan/lets-watch
```

## Change the base url

In the flutter project, go to ```lib/constants/environment.dart``` and update the base url with your own ip address.

```
static const baseUrl = 'rtmp://192.168.1.100:1935';
```


## Run Flutter project

Run the project with just a simple command
```
flutter run
```

### Create Party or Join Stream

You can see in the app, there are two buttons. Choose what you want to perform. 

### Create watch party

> Click on create party
<img width=300 src="https://raw.githubusercontent.com/sxudan/lets-watch/main/create_party.jpeg"/>

> Add Stream Name (mystream)

> Click Select Video and choose the video you want to publish

> Press Ok

> Click on Play button to broadcast


### View watch party

> Click on Join stream

> Input the stream name and click OK

> Click on Play button to Play

With the above docker image server you can play the stream using HLS streaming too
```
http://<ip-address>:8888/<stream-name>
```

# Screenshots

## Ingest
<img width=300 src="https://raw.githubusercontent.com/sxudan/lets-watch/main/IMG_1069.PNG"/>

## Streaming on VLC player
<img width=600 src="https://raw.githubusercontent.com/sxudan/lets-watch/main/Image2.png"/>

## Final Result
<img width=600 src="https://raw.githubusercontent.com/sxudan/lets-watch/main/sc.gif"/>
