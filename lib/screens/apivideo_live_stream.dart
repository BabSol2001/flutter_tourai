import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveStreamScreen extends StatefulWidget {
  final String rtmpUrl; 
  final String streamKey;

  const LiveStreamScreen({
    super.key,
    required this.rtmpUrl,
    required this.streamKey,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with WidgetsBindingObserver {
  // تعریف کنترلر اصلی پکیج
  late ApiVideoLiveStreamController _controller;
  
  // متغیرهای کنترلی برای مدیریت وضعیت رابط کاربری
  bool _isStreaming = false;
  bool _isInitialized = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    // ثبت مشاهده‌گر برای مدیریت تغییرات وضعیت اپلیکیشن (بستن/باز کردن)
    WidgetsBinding.instance.addObserver(this);
    _initializeController();
  }

  @override
  void dispose() {
    // حذف مشاهده‌گر و آزادسازی منابع کنترلر برای جلوگیری از نشت حافظه
    WidgetsBinding.instance.removeObserver(this);
    _controller.stopStreaming();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    // اگر اپلیکیشن به پس‌زمینه رفت، استریم متوقف شود (به دلیل محدودیت‌های سیستم‌عامل)
    if (state == AppLifecycleState.inactive) {
      _controller.stopStreaming();
    } else if (state == AppLifecycleState.resumed) {
      // بازگشت به اپلیکیشن و راه‌اندازی مجدد پیش‌نمایش دوربین
      _controller.startPreview();
    }
  }

  Future<void> _initializeController() async {
    // ۱. درخواست مجوزهای لازم به صورت همزمان
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    // بررسی اینکه آیا کاربر اجازه دسترسی داده است یا خیر
    if (statuses[Permission.camera]!.isDenied || statuses[Permission.microphone]!.isDenied) {
      if (mounted) _showErrorDialog('عدم دسترسی', 'لطفاً دسترسی دوربین و میکروفون را تایید کنید.');
      return;
    }

    // ۲. پیکربندی و ساخت کنترلر
    _controller = ApiVideoLiveStreamController(
      initialAudioConfig: AudioConfig(bitrate: 128 * 1024), // تنظیم کیفیت صدا
      initialVideoConfig: VideoConfig.withDefaultBitrate(), // تنظیمات پیش‌فرض ویدیو
      
      // کال‌بک‌های مربوط به وضعیت اتصال
      onConnectionSuccess: () {
        if (mounted) setState(() => _isStreaming = true);
      },
      onConnectionFailed: (error) {
        if (mounted) {
          setState(() => _isStreaming = false);
          _showErrorDialog('خطای اتصال', 'اتصال به سرور برقرار نشد: $error');
        }
      },
      onDisconnection: () {
        if (mounted) setState(() => _isStreaming = false);
      },
      onError: (error) {
        if (mounted) _showErrorDialog('خطا', error.toString());
      },
    );

    // ۳. راه‌اندازی فیزیکی دوربین و میکروفون
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) _showErrorDialog('خطای سیستمی', 'راه‌اندازی دوربین با مشکل مواجه شد.');
    }
  }

  // متد شروع استریم
  Future<void> _startStreaming() async {
    if (!_isInitialized) return;

    try {
      await _controller.startStreaming(
        url: widget.rtmpUrl,
        streamKey: widget.streamKey,
      );
    } catch (e) {
      _showErrorDialog('خطا', 'امکان شروع پخش زنده وجود ندارد.');
    }
  }

  // متد توقف استریم
  Future<void> _stopStreaming() async {
    try {
      await _controller.stopStreaming();
      if (mounted) setState(() => _isStreaming = false);
    } catch (e) {
      debugPrint('Error stopping stream: $e');
    }
  }

  // تغییر وضعیت بی‌صدا
  Future<void> _toggleMute() async {
    try {
      await _controller.toggleMute();
      setState(() => _isMuted = !_isMuted);
    } catch (e) {
      debugPrint('Error toggling mute: $e');
    }
  }

  // جابجایی بین دوربین جلو و عقب
  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('فهمیدم')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // ظاهر حرفه‌ای‌تر برای صفحه دوربین
      appBar: AppBar(
        title: const Text('پخش زنده (Live)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // نمایش پیش‌نمایش دوربین
           // بخش اصلاح شده در متد build
            Expanded(
              child: ClipRRect( // به جای Container از ClipRRect استفاده کنید
                borderRadius: BorderRadius.circular(12), // اگر مایلید لبه‌ها کمی گرد باشند
                child: _isInitialized
                    ? ApiVideoCameraPreview(controller: _controller)
                    : const Center(child: CircularProgressIndicator(color: Colors.orange)),
              ),
            ),
            
            // بخش دکمه‌های کنترلی
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.black87,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // دکمه چرخش دوربین
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, size: 32, color: Colors.white),
                    onPressed: _isInitialized ? _switchCamera : null,
                  ),
                  
                  // دکمه اصلی شروع/توقف
                  GestureDetector(
                    onTap: _isInitialized ? (_isStreaming ? _stopStreaming : _startStreaming) : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isStreaming ? Colors.red : Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isStreaming ? Icons.stop : Icons.videocam,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // دکمه صدا (Mute)
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      size: 32,
                      color: _isMuted ? Colors.red : Colors.white,
                    ),
                    onPressed: _isInitialized ? _toggleMute : null,
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