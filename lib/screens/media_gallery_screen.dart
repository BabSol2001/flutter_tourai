import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tourai/models/city.dart';

class MediaGalleryScreen extends StatefulWidget {
  final List<CityMedia> mediaItems;
  final int initialIndex;

  const MediaGalleryScreen({
    super.key,
    required this.mediaItems,
    this.initialIndex = 0,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  late CarouselSliderController _carouselController;
  late int _currentIndex;  // ← این متغیر جدید برای شمارنده دینامیک

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselSliderController();
    _currentIndex = widget.initialIndex;  // از ایندکس اولیه شروع می‌کنه
  }

  @override
  Widget build(BuildContext context) {
    // فقط رسانه‌های معتبر (تصویر با URL)
    final validMedia = widget.mediaItems.where(
      (m) => m.mediaType == 'image' && m.url != null && m.url!.isNotEmpty,
    ).toList();

    if (validMedia.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            'هیچ عکسی برای نمایش وجود ندارد',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            CarouselSlider(
              carouselController: _carouselController,
              options: CarouselOptions(
                height: MediaQuery.of(context).size.height * 0.85,
                viewportFraction: 1.0,
                initialPage: widget.initialIndex,
                enableInfiniteScroll: validMedia.length > 1,
                enlargeCenterPage: false,
                scrollDirection: Axis.horizontal,
                autoPlay: false,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentIndex = index;
                  });
                  print("DEBUG - صفحه گالری عوض شد به: $index");
                },
              ),
              items: validMedia.map((media) {
                return Image.network(
                  'http://192.168.0.145:8000${media.url}',
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 80),
                  ),
                );
              }).toList(),
            ),

            // فلش چپ
            Positioned(
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 40),
                onPressed: () => _carouselController.previousPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                ),
              ),
            ),

            // فلش راست
            Positioned(
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 40),
                onPressed: () => _carouselController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                ),
              ),
            ),

            // شمارنده دینامیک (مثل اینستاگرام)
            Positioned(
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${validMedia.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}