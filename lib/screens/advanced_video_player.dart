import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final bool isMini;
  final List<BetterPlayerSubtitlesSource>? subtitles;
  final Map<String, String>? qualities;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.isMini = false,
    this.subtitles,
    this.qualities,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late BetterPlayerController _controller;

  @override
  void initState() {
    super.initState();

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.videoUrl,
      subtitles: widget.subtitles ?? [],
      resolutions: widget.qualities,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 10000,                       // بزرگ‌تر از bufferForPlaybackMs
        maxBufferMs: 60000,
        bufferForPlaybackMs: 2500,                // شروع سریع
        bufferForPlaybackAfterRebufferMs: 5000,   // بعد از ریبافر
      ),
      useAsmsSubtitles: true,  // برای HLS subtitles
    );

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        autoPlay: true,
        looping: true,
        fit: BoxFit.contain,
        handleLifecycle: true,  // مدیریت lifecycle اپ (pause وقتی background)
        autoDispose: true,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          enablePlaybackSpeed: true,
          enableSubtitles: true,
          enableQualities: true,
          enableFullscreen: true,
          enablePip: true,
          enableSkips: true,
          enableOverflowMenu: true,
          // اگر controls سفارشی می‌خوای، می‌تونی playerTheme یا customControls تعریف کنی
        ),
      ),
      betterPlayerDataSource: dataSource,
    );
  }

  // متدهای کنترل از بیرون (برای carousel / PageView)
  void play() {
    _controller.play();
  }

  void pause() {
    _controller.pause();
  }

  bool get isPlaying => _controller.isPlaying() ?? false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = BetterPlayer(controller: _controller);

    return widget.isMini
        ? AspectRatio(
            aspectRatio: 16 / 9,
            child: player,
          )
        : player;
  }
}