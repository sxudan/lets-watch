import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lets_watch/StreamedList.dart';
import 'package:lets_watch/constants/environment.dart';
import 'ffmpeg_library.dart';

enum VideoStreamMode { Publish, View }

class VideoStream {
  VideoStream({required this.name, required this.mode});
  final String name;
  final VideoStreamMode mode;
}

enum PublishingState {
  Normal,
  RequestPublish,
  Publishing,
  RequestStopPublish,
}

enum StreamingState {
  Normal,
  RequestStream,
  Streaming,
  RequestStopStream,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final StreamedList<VideoStream> videoList = StreamedList();

  String? currentPlayingStream = null;
  String? currentSelectedFile = null;
  ValueNotifier<String> logs = ValueNotifier('');
  VlcPlayerController? _videoPlayerController;
  PublishingState _publishingState = PublishingState.Normal;
  StreamingState _streamingState = StreamingState.Normal;

  PublishingState get publishingState => _publishingState;
  StreamingState get streamingState => _streamingState;

  ScrollController _scrollController = ScrollController();

  set setLog(String log) {
    logs.value += '\n' + log;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  set streamingState(StreamingState state) {
    print(state);
    _streamingState = state;
    switch (state) {
      case StreamingState.RequestStream:
        initialiseVLC();
        break;
      case StreamingState.Streaming:
        _videoPlayerController?.initialize();
        break;
      case StreamingState.RequestStopStream:
        destroyVLC();
        break;
      default:
        break;
    }
  }

  set publishingState(PublishingState state) {
    print(state);
    _publishingState = state;
    switch (state) {
      case PublishingState.RequestPublish:
        streamingState = StreamingState.RequestStream;
        ingest();
        break;
      case PublishingState.Publishing:
        streamingState = StreamingState.Streaming;
        break;
      case PublishingState.RequestStopPublish:
        streamingState = StreamingState.RequestStopStream;
        cancelIngest();
        break;
      default:
        break;
    }
  }

  void initialiseVLC() async {
    await destroyVLC();
    _videoPlayerController = VlcPlayerController.network(
        '${Environment.baseUrl}/${currentPlayingStream!}',
        autoPlay: true,
        autoInitialize: false,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions(
            [
              VlcAdvancedOptions.networkCaching(50),
            ],
          ),
        ),
        hwAcc: HwAcc.full);
    _videoPlayerController?.addListener(onListen);
    _videoPlayerController?.addOnInitListener(onInit);
    _videoPlayerController?.addOnRendererEventListener(onRenderEvent);
  }

  @override
  void dispose() async {
    destroyVLC();
    super.dispose();
  }

  Future<void> destroyVLC() async {
    await _videoPlayerController?.stopRendererScanning();
    await _videoPlayerController?.dispose();
    _videoPlayerController?.removeListener(onListen);
    _videoPlayerController?.removeOnInitListener(onInit);
    _videoPlayerController?.removeOnRendererEventListener(onRenderEvent);
    setLog = 'Destroyed VLC';
    _videoPlayerController = null;
    _videoPlayerController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Watch Party')),
      body: SafeArea(
        child: StreamBuilder(
          stream: videoList.data,
          builder: (context, snapshot) {
            print('Rebuilding');
            var data = snapshot.data ?? [];
            return buildBody(data);
          },
        ),
      ),
    );
  }

  void onInit() {
    if (!mounted) return;
    print('On Initialised');
    setState(() {});
  }

  void onListen() {
    if (!mounted) return;
    // print('On Listening');
  }

  void onRenderEvent(VlcRendererEventType type, String s1, String s2) {
    print(type);
    print(s1);
    print(s2);
  }

  Widget buildPlayer() {
    return Container(
      color: Colors.black,
      child: VlcPlayer(
        controller: _videoPlayerController!,
        aspectRatio: 16 / 9,
      ),
    );
  }

  Widget buildBody(List<VideoStream> videos) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              child: Text('Create Party'),
              onPressed: onAddStream,
            ),
            TextButton(
              child: Text('Join stream'),
              onPressed: onJoinStream,
            )
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          itemCount: videos.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: videos[index].mode == VideoStreamMode.Publish
                  ? Icon(Icons.broadcast_on_home)
                  : Icon(Icons.remove_red_eye),
              title: Text(videos[index].name),
              trailing: IconButton(
                icon: Icon(currentPlayingStream == videos[index].name
                    ? Icons.pause
                    : Icons.play_arrow),
                onPressed: () {
                  if (videos[index].mode == VideoStreamMode.Publish) {
                    if (currentPlayingStream == null) {
                      currentPlayingStream = videos[index].name;
                      publishingState = PublishingState.RequestPublish;
                    } else {
                      currentPlayingStream = null;
                      publishingState = PublishingState.RequestStopPublish;
                    }
                  } else {
                    if (currentPlayingStream == null) {
                      currentPlayingStream = videos[index].name;
                      streamingState = StreamingState.RequestStream;
                      Future.delayed(Duration(seconds: 1), () {
                        streamingState = StreamingState.Streaming;
                      });
                    } else {
                      currentPlayingStream = null;
                      streamingState = StreamingState.RequestStopStream;
                    }
                  }
                  setState(() {});
                },
              ),
            );
          },
        ),
        SizedBox(
          height: 16,
        ),
        if (_videoPlayerController != null) buildPlayer(),
        SizedBox(
          height: 16,
        ),
        buildLogboard()
      ],
    );
  }

  void onJoinStream() async {
    var textFieldController = TextEditingController();
    currentSelectedFile = null;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) {
          return AlertDialog(
            title: Text('Add new stream'),
            content: Container(
              height: 150,
              child: Column(
                children: [
                  TextField(
                    controller: textFieldController,
                    decoration: new InputDecoration(hintText: 'Stream Name'),
                  ),
                  SizedBox(
                    height: 16,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  videoList.updateList(
                    [
                      VideoStream(
                          name: textFieldController.text,
                          mode: VideoStreamMode.View)
                    ],
                  );
                  setLog = '${textFieldController.text} added';
                  Navigator.pop(context);
                },
                child: Text('OK'),
              )
            ],
          );
        },
      ),
    );
  }

  void onAddStream() async {
    var textFieldController = TextEditingController();
    currentSelectedFile = null;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) {
          return AlertDialog(
            title: Text('Add new stream'),
            content: Container(
              height: 150,
              child: Column(
                children: [
                  TextField(
                    controller: textFieldController,
                    decoration: new InputDecoration(hintText: 'Stream Name'),
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  Text(
                    currentSelectedFile ?? '',
                    maxLines: 1,
                  ),
                  TextButton(
                    child: Text('Select Video'),
                    onPressed: () async {
                      var f = await ImagePicker()
                          .pickVideo(source: ImageSource.gallery);
                      if (f == null) {
                        return;
                      }
                      var inputPath = f.path;

                      set(() {
                        currentSelectedFile = inputPath;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  videoList.updateList(
                    [
                      VideoStream(
                          name: textFieldController.text,
                          mode: VideoStreamMode.Publish)
                    ],
                  );
                  setLog = '${textFieldController.text} added';
                  Navigator.pop(context);
                },
                child: Text('OK'),
              )
            ],
          );
        },
      ),
    );
  }

  Widget buildLogboard() {
    return ValueListenableBuilder(
      valueListenable: logs,
      builder: (context, value, child) => Container(
        padding: EdgeInsets.all(16),
        height: 150,
        width: double.infinity,
        color: Colors.black,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void ingest() {
    print(
        '-re  -i ${currentSelectedFile!} -c:a aac -c:v h264 -b:v 2M  -f flv ${Environment.baseUrl}/${currentPlayingStream!}');
    try {
      FFmpegKitConfig.setLogLevel(Level.avLogVerbose);
      FFmpegKit.executeAsync(
          '-re  -i ${currentSelectedFile!} -c:a aac -c:v h264 -b:v 2M  -f flv ${Environment.baseUrl}/${currentPlayingStream!}',
          // '-f h264 -thread_queue_size 4096 -vsync drop -i ${inputPath} -f h264 -ar 44100 -ac 2 -acodec pcm_s16le -thread_queue_size 4096 -i ${inputPath} -vcodec copy -acodec aac -ab 128k -f fifo -fifo_format flv -map 0:v -map 1:a -drop_pkts_on_overflow 1 -attempt_recovery 1 -recovery_wait_time 1 rtmp://192.168.1.100:1935/mystream',
          (c) {}, (log) {
        setLog = '\n' + log.getMessage();
        // print(log.getMessage());
      }, (stats) {
        if (publishingState == PublishingState.RequestPublish) {
          publishingState = PublishingState.Publishing;
          setState(() {});
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void cancelIngest() {
    FFmpegKit.cancel().then((value) {
      publishingState = PublishingState.Normal;
    });
  }
}
