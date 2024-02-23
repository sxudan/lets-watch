import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:images_picker/images_picker.dart';
import 'package:lets_watch/constants/environment.dart';
import 'package:live_file_publisher/live_file_publisher.dart';
import 'package:video_compress/video_compress.dart';

enum VideoStreamType { Publish, View }

class VideoStream {
  VideoStream(
      {required this.name,
      required this.type,
      required this.startOffset,
      this.path});
  final String name;
  final String? path;
  final VideoStreamType type;
  final String startOffset;
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
  ValueNotifier<String> logs = ValueNotifier('');
  VlcPlayerController? _videoPlayerController;
  StreamingState _streamingState = StreamingState.Normal;

  StreamingState get streamingState => _streamingState;

  ScrollController _scrollController = ScrollController();

  double videoAspectRatio = 16 / 9;

  bool isPlaying = false;

  String startTimeOffset = '00:00:00';

  late Subscription _subscription;

  ValueNotifier<double> compressProgress = ValueNotifier(0.0);

  LiveFilePublisher filePublisher = LiveFilePublisher();

  VideoStream? currentBroadcastingStream;
  VideoStream? currentPlayingStream;

  @override
  void initState() {
    super.initState();
    _subscription = VideoCompress.compressProgress$.subscribe((progress) {
      debugPrint('progress: ${double.parse('$progress')}');
      compressProgress.value = double.parse('$progress');
    });
    filePublisher.addStateListener(onStateListener);
    filePublisher.addErrorListener(onErrorListener);
    filePublisher.addLogListener(onLogListener);
  }

  void onStateListener(PublishingState state) {
    print(state);
    setState(() {});
  }

  void onErrorListener(Object error) {
    print(error);
  }

  void onLogListener(String log) {
    setLog = log;
  }

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

  void initialiseVLC() async {
    await destroyVLC();
    _videoPlayerController = VlcPlayerController.network(
      '${Environment.baseUrl}/${currentPlayingStream!.name}',
      autoPlay: true,
      autoInitialize: false,
      allowBackgroundPlayback: true,
      options: VlcPlayerOptions(
        // rtp: VlcRtpOptions([VlcRtpOptions.rtpOverRtsp(false)]),
        // audio: VlcAudioOptions([VlcAudioOptions.audioTimeStretch(true)]),
        // video: VlcVideoOptions([
        //   VlcVideoOptions.skipFrames(true),
        //   VlcVideoOptions.dropLateFrames(true)
        // ]),
        advanced: VlcAdvancedOptions(
          [
            VlcAdvancedOptions.networkCaching(0),
            VlcAdvancedOptions.clockSynchronization(0),
            VlcAdvancedOptions.liveCaching(0),
          ],
        ),
      ),
      hwAcc: HwAcc.auto,
    );
    _videoPlayerController?.addListener(onListen);
    _videoPlayerController?.addOnInitListener(onInit);
    _videoPlayerController?.addOnRendererEventListener(onRenderEvent);
  }

  @override
  void dispose() async {
    destroyVLC();
    super.dispose();
    _subscription.unsubscribe();
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
    streamingState = StreamingState.Normal;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Watch Party')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: buildBody(),
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

  Widget buildBody() {
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
        if (currentBroadcastingStream != null)
          ListTile(
            leading: Icon(Icons.broadcast_on_home),
            title: Text(currentBroadcastingStream!.name),
            subtitle: Text(
                '${filePublisher.baseUrl}/${currentBroadcastingStream!.name}'),
            trailing: IconButton(
              icon: Icon(
                  filePublisher.publishingState == PublishingState.Publishing
                      ? Icons.stop
                      : Icons.publish),
              onPressed: () {
                if (currentBroadcastingStream!.type ==
                    VideoStreamType.Publish) {
                  print('Publish called');
                  if (filePublisher.publishingState == PublishingState.Normal) {
                    try {
                      filePublisher.connect(
                          url: Environment.baseRtspUrl,
                          mode: PublisherProtocol.RTSP_UDP);
                      filePublisher.publish(
                          startTime: currentBroadcastingStream!.startOffset,
                          filePath: currentBroadcastingStream!.path ?? '',
                          name: currentBroadcastingStream!.name);
                    } catch (e) {
                      print(e);
                    }
                  } else {
                    filePublisher.stop();
                  }
                }
                setState(() {});
              },
            ),
          ),
        if (currentPlayingStream != null)
          ListTile(
            leading: Icon(Icons.remove_red_eye),
            title: Text(currentPlayingStream!.name),
            trailing: IconButton(
              icon: Icon(streamingState == StreamingState.Streaming
                  ? Icons.pause
                  : Icons.play_arrow),
              onPressed: () {
                if (currentPlayingStream!.type == VideoStreamType.View) {
                  if (streamingState == StreamingState.Normal) {
                    streamingState = StreamingState.RequestStream;
                    Future.delayed(Duration(seconds: 2), () {
                      streamingState = StreamingState.Streaming;
                    });
                  } else {
                    streamingState = StreamingState.RequestStopStream;
                  }
                }
                setState(() {});
              },
            ),
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
                  currentPlayingStream = VideoStream(
                    name: textFieldController.text,
                    type: VideoStreamType.View,
                    startOffset: '00:00:00',
                  );
                  setLog = '${textFieldController.text} added';
                  Navigator.pop(context);
                  setState(() {});
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
    var useDefaultCompressiong = false;
    var currentSelectedFile = null;
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
                  Row(
                    children: [
                      Expanded(
                          child: Text(
                        'Default compression (Faster)',
                        maxLines: 5,
                      )),
                      Expanded(child: SizedBox()),
                      SizedBox(
                        width: 70,
                        child: Switch(
                            value: useDefaultCompressiong,
                            onChanged: (v) {
                              set(() {
                                useDefaultCompressiong = v;
                              });
                            }),
                      )
                    ],
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
                      if (useDefaultCompressiong) {
                        var f = await ImagePicker()
                            .pickVideo(source: ImageSource.gallery);
                        if (f == null) {
                          return;
                        }
                        var inputPath = f.path;

                        set(() {
                          currentSelectedFile = inputPath;
                        });
                      } else {
                        var c = await ImagesPicker.pick(
                            quality: 1,
                            pickType: PickType.video,
                            count: 1,
                            maxTime: 5 * 60 * 60);
                        if (c == null || c.length == 0) {
                          return;
                        }
                        var inputPath = c[0].path;

                        var result = await VideoCompress.compressVideo(
                          inputPath,
                          quality: VideoQuality.Res1280x720Quality,
                        );

                        if (result == null || result.file == null) {
                          return;
                        }

                        set(() {
                          currentSelectedFile = result.file!.path;
                        });
                      }
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: compressProgress,
                    builder: (context, value, child) => LinearProgressIndicator(
                      value: value / 100,
                    ),
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
                onPressed: () async {
                  await VideoCompress.cancelCompression();
                  await VideoCompress.deleteAllCache();
                  compressProgress.value = 0;
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  currentBroadcastingStream = VideoStream(
                      name: textFieldController.text,
                      type: VideoStreamType.Publish,
                      path: currentSelectedFile,
                      startOffset:
                          '${hhFieldController.text}:${mmFieldController.text}:${ssFieldController.text}');
                  setLog = '${textFieldController.text} added';
                  Navigator.pop(context);
                  setState(() {});
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
}
