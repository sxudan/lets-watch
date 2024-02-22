# lets-watch
This is a watch party video streaming app

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


# Screenshots

## Ingest
<img width=300 src="https://raw.githubusercontent.com/sxudan/lets-watch/main/IMG_1069.PNG"/>

## Streaming on VLC player
<img width=600 src="https://raw.githubusercontent.com/sxudan/lets-watch/main/Image2.png"/>

## Final Result
<img width=600 src="https://raw.githubusercontent.com/sxudan/lets-watch/main/sc.gif"/>
