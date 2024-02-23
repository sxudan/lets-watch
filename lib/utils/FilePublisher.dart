import 'dart:async';
import 'package:flutter/material.dart';

import '../ffmpeg_library.dart';

enum PublisherProtocol {
  RTMP,
  RTSP_UDP,
  RTSP_TCP,
}

enum PublishingState {
  Normal,
  RequestPublish,
  Publishing,
  RequestStopPublish,
}

abstract class FilePublisherBase {
  void publish(
      {required String filePath, required String name, String? startTime});
  void stop();
  void addStateListener(Function(PublishingState)? listener);
  void addErrorListener(Function(Object error)? errorListener);
  void addLogListener(Function(String log)? logListener);
}

class FilePublisher extends ChangeNotifier implements FilePublisherBase {
  FilePublisher({required this.mode, required this.baseUrl});
  final PublisherProtocol mode;
  final String baseUrl;
  String? _name;
  String? _filePath;
  String? _startTime;

  PublishingState _publishingState = PublishingState.Normal;
  PublishingState get publishingState => _publishingState;

  Function(PublishingState)? _listener;
  Function(Object error)? _errorListener;
  Function(String log)? _logListener;

  set publishingState(PublishingState state) {
    _publishingState = state;
    _listener?.call(state);
    switch (state) {
      case PublishingState.RequestPublish:
        if (_filePath == null || _filePath == '') {
          setError('File path is null');
          return;
        }
        if (_name == null) {
          setError('Stream name is null');
          return;
        }
        _ingest(
            offsetStartTime: _startTime,
            onStats: (stats) {
              if (_publishingState == PublishingState.RequestPublish) {
                publishingState = PublishingState.Publishing;
              }
            });
        break;
      case PublishingState.Publishing:
        break;
      case PublishingState.RequestStopPublish:
        _cancelIngest();
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void setError(String msg) {
    _errorListener?.call({'message': msg});
  }

  @override
  void addStateListener(Function(PublishingState state)? listener) {
    _listener = listener;
  }

  @override
  void publish(
      {required String filePath, required String name, String? startTime}) {
    _filePath = filePath;
    _name = name;
    _startTime = startTime;
    publishingState = PublishingState.RequestPublish;
  }

  @override
  void stop() {
    publishingState = PublishingState.RequestStopPublish;
  }

  void _ingest(
      {Function(String)? onLog,
      Function(Statistics)? onStats,
      Function(Object)? onError,
      String? offsetStartTime}) {
    // String cmd =
    //     '${offsetStartTime == null ? "" : "-ss $offsetStartTime"} -re -i ${filePath} -c:v h264 -b:v 2M -vf "scale=1920:1080" -s 1920x1080 -preset ultrafast -c:a copy -color_primaries bt709 -color_trc bt709 -colorspace bt709 -threads 4 -f flv ${Environment.baseUrl}/${name}';
    String cmd =
        '${offsetStartTime == null ? "" : "-ss $offsetStartTime"} -re  -i ${_filePath} -c:a aac -c:v h264 -b:v 2M ';
    if (mode == PublisherProtocol.RTMP) {
      cmd += '-f flv ${baseUrl}/${_name}';
    } else if (mode == PublisherProtocol.RTSP_UDP) {
      cmd += '-f rtsp ${baseUrl}/${_name}';
    } else {
      cmd += '-f rtsp -rtsp_transport tcp ${baseUrl}/${_name}';
    }
    _logListener?.call(cmd);
    try {
      FFmpegKitConfig.setLogLevel(Level.avLogVerbose);
      FFmpegKit.executeAsync(
        cmd,
        // '-f h264 -thread_queue_size 4096 -vsync drop -i ${inputPath} -f h264 -ar 44100 -ac 2 -acodec pcm_s16le -thread_queue_size 4096 -i ${inputPath} -vcodec copy -acodec aac -ab 128k -f fifo -fifo_format flv -map 0:v -map 1:a -drop_pkts_on_overflow 1 -attempt_recovery 1 -recovery_wait_time 1 rtmp://192.168.1.100:1935/mystream',
        (c) async {
          _logListener?.call(await c.getOutput() ?? '');
          var returnCode = await c.getReturnCode();
          if (returnCode == ReturnCode.cancel) {
            setError(await c.getOutput() ?? '');
          }
        },
        (log) {
          _logListener?.call(log.getMessage());
          // print(log.getMessage());
        },
        (stats) {
          onStats?.call(stats);
        },
      );
    } catch (e) {
      print(e);
      onError?.call(e);
    }
  }

  Future<void> _cancelIngest() async {
    await FFmpegKit.cancel();
    publishingState = PublishingState.Normal;
  }

  @override
  void addErrorListener(Function(Object error)? errorListener) {
    _errorListener = errorListener;
  }

  @override
  void addLogListener(Function(String log)? logListener) {
    _logListener = logListener;
  }
}
