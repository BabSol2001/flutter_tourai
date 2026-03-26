import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveStreamScreen extends StatefulWidget {
  final String rtmpUrl;     // rtmp://your-server/live
  final String streamKey;   // کلید استریم

  const LiveStreamScreen({
    super.key,
    required this.rtmpUrl,
    required this.streamKey,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with WidgetsBindingObserver {
  BetterPlayerController? _playerController;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  bool _isStreaming = false;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _useFrontCamera = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerController?.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initialize() async {
    // درخواست مجوزها
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (!mounted) return;

    if (statuses[Permission.camera]!.isDenied || statuses[Permission.microphone]!.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً دسترسی دوربین و میکروفون را بدهید')),
      );
      return;
    }

    // لود دوربین‌ها یک بار
    try {
      _cameras = await availableCameras();
      await _initializeCamera();
    } catch (e) {
      debugPrint('خطا در لود دوربین‌ها: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در دسترسی به دوربین: $e')),
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    try {
      final selectedCamera = _useFrontCamera
          ? _cameras!.firstWhere((c) => c.lensDirection == CameraLensDirection.front)
          : _cameras!.firstWhere((c) => c.lensDirection == CameraLensDirection.back);

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('خطا در راه‌اندازی دوربین: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در دوربین: $e')),
        );
      }
    }
  }

  Future<void> _startStreaming() async {
    if (!_isInitialized) return;

    try {
      // ۱. فرض می‌کنیم بک‌اند HLS URL رو آماده کرده (یا بعد از شروع استریم می‌ده)
      final hlsUrl = await _getHlsUrlFromBackend();

      if (hlsUrl.isEmpty) throw Exception('HLS URL دریافت نشد');

      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        hlsUrl,
        bufferingConfiguration: const BetterPlayerBufferingConfiguration(
          minBufferMs: 15000,
          maxBufferMs: 60000,
          bufferForPlaybackMs: 5000,
        ),
      );

      _playerController = BetterPlayerController(
        const BetterPlayerConfiguration(
          aspectRatio: 16 / 9,
          autoPlay: true,
          looping: false,
          fit: BoxFit.contain,
          handleLifecycle: true,
        ),
        betterPlayerDataSource: dataSource,
      );

      if (mounted) setState(() => _isStreaming = true);
    } catch (e) {
      debugPrint('خطا در شروع پخش: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در شروع پخش زنده: $e')),
        );
      }
    }
  }

  Future<String> _getHlsUrlFromBackend() async {
    // این تابع رو با ApiService واقعی جایگزین کن
    // مثلاً: await ApiService().startLive(widget.streamKey);
    await Future.delayed(const Duration(seconds: 2)); // شبیه‌سازی
    return 'http://your-server/hls/${widget.streamKey}.m3u8';
  }

  Future<void> _stopStreaming() async {
    await _playerController?.pause();
    _playerController?.dispose();
    _playerController = null;

    if (mounted) setState(() => _isStreaming = false);
  }

  Future<void> _toggleMute() async {
    if (_playerController == null) return;

    try {
      final newVolume = _isMuted ? 1.0 : 0.0;
      await _playerController!.setVolume(newVolume);
      if (mounted) setState(() => _isMuted = !_isMuted);
    } catch (e) {
      debugPrint('خطا در تغییر صدا: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (!_isInitialized || _cameras == null) return;

    setState(() => _useFrontCamera = !_useFrontCamera);
    await _cameraController?.dispose();
    _cameraController = null;
    await _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('پخش زنده'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isStreaming && _playerController != null
                    ? BetterPlayer(controller: _playerController!)
                    : _isInitialized && _cameraController != null && _cameraController!.value.isInitialized
                        ? CameraPreview(_cameraController!)
                        : const Center(child: CircularProgressIndicator(color: Colors.orange)),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.black87,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      _useFrontCamera ? Icons.flip_camera_ios : Icons.flip_camera_android,
                      size: 32,
                      color: Colors.white,
                    ),
                    onPressed: _isInitialized ? _switchCamera : null,
                  ),

                  GestureDetector(
                    onTap: _isInitialized
                        ? (_isStreaming ? _stopStreaming : _startStreaming)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isStreaming ? Colors.red : Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isStreaming ? Icons.stop : Icons.videocam,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      size: 32,
                      color: _isMuted ? Colors.red : Colors.white,
                    ),
                    onPressed: _isStreaming ? _toggleMute : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}