import 'package:flutter/material.dart';
import 'package:flutter_tourai/services/api_service.dart';
import 'package:flutter_tourai/models/city.dart';           // مدل Live
import 'advanced_video_player.dart'; // پخش ضبط‌شده
import 'live_viewer_screen.dart';     // پخش زنده
import 'package:cached_network_image/cached_network_image.dart';

class CityLiveTab extends StatefulWidget {
  final int cityId;
  final Future<List<Live>> livesFuture;

  const CityLiveTab({
    super.key,
    required this.cityId,
    required this.livesFuture,
  });

  @override
  State<CityLiveTab> createState() => _CityLiveTabState();
}

class _CityLiveTabState extends State<CityLiveTab> {
  late Future<List<Live>> _livesFuture;
  final ApiService _apiService = ApiService();
  bool _hasActiveLive = false;

  @override
  void initState() {
    super.initState();
    _livesFuture = widget.livesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _livesFuture = _apiService.getLives(widget.cityId);
        });
        // منتظر می‌مونیم تا داده جدید بیاد (اختیاری اما UX بهتر)
        await _livesFuture.catchError((_) {});
      },
      child: FutureBuilder<List<Live>>(
        future: _livesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'خطا در بارگذاری لایوها: ${snapshot.error.toString().split('\n').first}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _livesFuture = _apiService.getLives(widget.cityId);
                      });
                    },
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            );
          }

          final lives = snapshot.data ?? [];

          // بروزرسانی وضعیت لایو زنده (هر بار که داده تغییر می‌کنه)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasActiveLive = lives.any((l) => l.isActive == true);
              });
            }
          });

          if (lives.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.live_tv, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('هنوز لایوی برای این شهر ثبت نشده', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return Stack(
            children: [
              GridView.builder(
                physics: const BouncingScrollPhysics(), // اسکرول نرم‌تر
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: lives.length,
                itemBuilder: (context, index) => _buildLiveCard(lives[index]),
              ),

              // نوتیفیکیشن اینستاگرام‌مانند
              if (_hasActiveLive)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 12),
                        SizedBox(width: 8),
                        Text(
                          'لایو زنده در حال پخش',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLiveCard(Live live) {
    final isLive = live.isActive == true;
    final thumbnailUrl = _apiService.getFullMediaUrl(live.thumbnailUrl ?? '');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openLive(live),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[900],
                child: const Icon(Icons.broken_image, size: 50, color: Colors.white),
              ),
            ),

            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),

            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    live.title ?? 'بدون عنوان',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isLive) ...[
                        const Icon(Icons.circle, color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${live.viewerCount ?? 0} نفر',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ] else
                        const Text(
                          'ضبط‌شده',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            if (isLive)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openLive(Live live) {
    final playbackUrl = live.playbackUrl?.trim();

    if (playbackUrl == null || playbackUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل پخش در دسترس نیست')),
      );
      return;
    }

    if (live.isActive == true) {
      // پخش زنده (HLS)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveViewerScreen(hlsUrl: playbackUrl),
        ),
      );
    } else {
      // پخش ضبط‌شده
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(videoUrl: playbackUrl),
        ),
      );
    }
  }
}