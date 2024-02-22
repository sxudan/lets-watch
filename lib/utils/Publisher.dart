import 'dart:async';

import 'package:lets_watch/constants/environment.dart';

import '../ffmpeg_library.dart';

class Publisher {
  static void ingest(
      {required String filePath,
      required String name,
      Function(String)? onLog,
      Function(Statistics)? onStats,
      Function(Object)? onError,
      String? offsetStartTime}) {
    String cmd =
        '${offsetStartTime == null ? "" : "-ss $offsetStartTime"} -re  -i ${filePath} -c:a aac -c:v h264 -b:v 2M  -f flv ${Environment.baseUrl}/${name}';
    print(cmd);
    try {
      FFmpegKitConfig.setLogLevel(Level.avLogVerbose);
      FFmpegKit.executeAsync(
        cmd,
        // '-f h264 -thread_queue_size 4096 -vsync drop -i ${inputPath} -f h264 -ar 44100 -ac 2 -acodec pcm_s16le -thread_queue_size 4096 -i ${inputPath} -vcodec copy -acodec aac -ab 128k -f fifo -fifo_format flv -map 0:v -map 1:a -drop_pkts_on_overflow 1 -attempt_recovery 1 -recovery_wait_time 1 rtmp://192.168.1.100:1935/mystream',
        (c) {},
        (log) {
          onLog?.call(log.getMessage());
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

  static Future<void> cancelIngest() async {
    Completer completer = Completer();
    FFmpegKit.cancel().then((value) {
      completer.complete();
    }).catchError((error) {
      completer.completeError(error);
    });
    return completer.future;
  }
}
