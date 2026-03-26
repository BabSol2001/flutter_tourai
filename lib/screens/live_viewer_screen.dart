// lib/screens/live_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';

class LiveViewerScreen extends StatefulWidget {
  final String hlsUrl;

  const LiveViewerScreen({super.key, required this.hlsUrl});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> with WidgetsBindingObserver {
  BetterPlayerController? _controller;
  bool _isBuffering = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;

    if (state == AppLifecycleState.paused) {
      _controller!.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller!.play();
    }
  }

  Future<void> _initializePlayer() async {
    if (widget.hlsUrl.trim().isEmpty) {
      setState(() {
        _errorMessage = 'آدرس پخش معتبر نیست';
        _isBuffering = false;
      });
      return;
    }

    try {
      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.hlsUrl.trim(),
        bufferingConfiguration: const BetterPlayerBufferingConfiguration(
          minBufferMs: 15000,
          maxBufferMs: 60000,
          bufferForPlaybackMs: 5000,
          bufferForPlaybackAfterRebufferMs: 10000,
        ),
      );

      _controller = BetterPlayerController(
        BetterPlayerConfiguration(
          aspectRatio: 16 / 9,
          autoPlay: true,
          looping: false,
          fit: BoxFit.contain,
          handleLifecycle: true,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                'خطا در پخش: $errorMessage',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          },
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            enablePlaybackSpeed: true,
            enableFullscreen: true,
            enableQualities: true,
            enableSubtitles: true,
            enableProgressBar: true,
            enableProgressBarDrag: true,
            enableOverflowMenu: true,
            controlBarColor: Colors.black54,
          ),
        ),
        betterPlayerDataSource: dataSource,
      );

      // گوش دادن به رویدادهای بافرینگ
      _controller!.addEventsListener((event) {
        if (!mounted) return;
        if (event.betterPlayerEventType == BetterPlayerEventType.bufferingStart) {
          setState(() => _isBuffering = true);
        } else if (event.betterPlayerEventType == BetterPlayerEventType.bufferingEnd ||
                   event.betterPlayerEventType == BetterPlayerEventType.play) {
          setState(() => _isBuffering = false);
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          setState(() {
            _errorMessage = event.parameters?['error']?.toString() ?? 'خطای ناشناخته';
            _isBuffering = false;
          });
        }
      });

      if (mounted) setState(() => _isBuffering = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطا در راه‌اندازی پخش: $e';
          _isBuffering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('پخش زنده'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // پخش‌کننده اصلی
          _controller != null
              ? BetterPlayer(controller: _controller!)
              : const Center(child: CircularProgressIndicator(color: Colors.white)),

          // لایه لودینگ/خطا
          if (_isBuffering)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('در حال بارگذاری...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),

          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 80, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _initializePlayer,
                      child: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}