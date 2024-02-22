import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lets_watch/StreamedList.dart';
import 'package:lets_watch/constants/environment.dart';
import 'package:lets_watch/utils/Publisher.dart';

enum VideoStreamMode { Publish, View }

class VideoStream {
  VideoStream(
      {required this.name, required this.mode, required this.startOffset});
  final String name;
  final VideoStreamMode mode;
  final String startOffset;
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

  double videoAspectRatio = 16 / 9;

  bool isPlaying = false;

  String startTimeOffset = '00:00:00';

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
    setState(() {});
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
    videoAspectRatio = _videoPlayerController?.value.aspectRatio ?? 16 / 9;
    setState(() {});
  }

  void onListen() {
    if (!mounted) return;
    // print('On Listening');
    var currentIsPlaying = _videoPlayerController?.value.isPlaying ?? false;
    if (isPlaying != currentIsPlaying) {
      isPlaying = currentIsPlaying;
      setState(() {});
    }
  }

  void onRenderEvent(VlcRendererEventType type, String s1, String s2) {
    print(type);
    print(s1);
    print(s2);
  }

  Widget buildPlayer() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          VlcPlayer(
            controller: _videoPlayerController!,
            aspectRatio: videoAspectRatio,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 44,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (isPlaying) {
                        _videoPlayerController?.pause();
                      } else {
                        _videoPlayerController?.play();
                      }
                      setState(() {});
                    },
                    icon:
                        isPlaying ? Icon(Icons.pause) : Icon(Icons.play_arrow),
                  ),
                  SizedBox(
                    width: 16,
                  ),
                ],
              ),
            ),
          )
        ],
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
                      startTimeOffset = videos[index].startOffset;
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
        const SizedBox(
          height: 16,
        ),
        if (_videoPlayerController != null) buildPlayer(),
        const SizedBox(
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
            title: Text('Join stream'),
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
                        mode: VideoStreamMode.View,
                        startOffset: '00:00:00',
                      ),
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
    var hhFieldController = TextEditingController(text: '00');
    var mmFieldController = TextEditingController(text: '00');
    var ssFieldController = TextEditingController(text: '00');
    currentSelectedFile = null;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) {
          return AlertDialog(
            title: Text('Add new stream'),
            content: Container(
              height: 300,
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
                  SizedBox(
                    height: 16,
                  ),
                  Text('Start time'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        child: TextField(
                          controller: hhFieldController,
                          textAlign: TextAlign.center,
                          decoration: new InputDecoration(hintText: 'hh'),
                        ),
                      ),
                      Container(
                        width: 50,
                        child: Text(
                          ':',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        child: TextField(
                          controller: mmFieldController,
                          textAlign: TextAlign.center,
                          decoration: new InputDecoration(hintText: 'mm'),
                        ),
                      ),
                      Container(
                        width: 50,
                        child: Text(
                          ':',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        child: TextField(
                          controller: ssFieldController,
                          textAlign: TextAlign.center,
                          decoration: new InputDecoration(hintText: 'ss'),
                        ),
                      ),
                    ],
                  )
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
                          mode: VideoStreamMode.Publish,
                          startOffset:
                              '${hhFieldController.text}:${mmFieldController.text}:${ssFieldController.text}')
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
    Publisher.ingest(
        filePath: currentSelectedFile!,
        name: currentPlayingStream!,
        offsetStartTime: startTimeOffset,
        onLog: (log) {
          setLog = '\n' + log;
        },
        onStats: (stats) {
          if (publishingState == PublishingState.RequestPublish) {
            publishingState = PublishingState.Publishing;
            setState(() {});
          }
        },
        onError: (error) {
          print(error);
        });
  }

  void cancelIngest() {
    Publisher.cancelIngest().then((value) {
      publishingState = PublishingState.Normal;
    });
  }
}
