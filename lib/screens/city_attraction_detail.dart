import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
// اگر ویدیو هم داری
import '../models/city.dart'; // فرض می‌کنیم مدل Attraction داخلش هست
import '../services/api_service.dart'; // برای لایک، کامنت، ستاره

//const String baseUrl = 'http://192.168.0.147:8000';

class CityAttractionDetailScreen extends StatefulWidget {
  final int cityId;
  final int initialAttractionId;

  const CityAttractionDetailScreen({
    super.key,
    required this.cityId,
    required this.initialAttractionId,
  });

  @override
  State<CityAttractionDetailScreen> createState() => _CityAttractionDetailScreenState();
}

class _CityAttractionDetailScreenState extends State<CityAttractionDetailScreen> {
  late Future<List<Attraction>> _attractionsFuture;
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _attractionsFuture = _apiService.getAttractions(widget.cityId);
    // پیدا کردن ایندکس اولیه برای اسکرول به جاذبه انتخاب‌شده
    _attractionsFuture.then((attractions) {
      final initialIndex = attractions.indexWhere((a) => a.id == widget.initialAttractionId);
      if (initialIndex != -1) {
        setState(() => _currentPage = initialIndex);
        _pageController.jumpToPage(initialIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: FutureBuilder<List<Attraction>>(
      future: _attractionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطا: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('جاذبه‌ای یافت نشد', style: TextStyle(color: Colors.white)));
        }

        final attractions = snapshot.data!;

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: attractions.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            final attraction = attractions[index];
            return _buildAttractionPost(attraction);
          },
        );
      },
    ),
  );
}
Widget _buildAttractionPost(Attraction attraction) {
  return Stack(
    fit: StackFit.expand,
    children: [
      // پس‌زمینه یا carousel رسانه‌ها
      if (attraction.mediaItems.isNotEmpty)
        _buildMediaContent(attraction.mediaItems)
      else
        Container(color: Colors.grey[900]),

      // لایه محتوا (کپشن، لایک، کامنت، ستاره)
      SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // هدر بالا (نام جاذبه + بستن)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    attraction.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // توضیحات (وسط پایین)
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Text(
                    attraction.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            // نوار پایین (لایک، کامنت، امتیاز)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.favorite,
                    count: attraction.likeCount,
                    color: Colors.red,
                    onTap: () => _toggleLike(attraction),
                  ),
                  _buildActionButton(
                    icon: Icons.comment,
                    count: attraction.comments.length,
                    color: Colors.blue,
                    onTap: () => _showCommentsBottomSheet(attraction),
                  ),
                  _buildActionButton(
                    icon: Icons.star,
                    count: attraction.averageRating.toStringAsFixed(1),
                    color: Colors.amber,
                    onTap: () => _showRatingDialog(attraction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}  
  
Widget _buildMediaContent(List<BaseMedia> mediaItems) {
  if (mediaItems.isEmpty) {
    return Container(color: Colors.grey[900]);
  }

  // تک رسانه
  if (mediaItems.length == 1) {
    final media = mediaItems.first;
    final mediaUrl = ApiService().getFullMediaUrl(media.url);

    if (media.mediaType == 'video') {
      // TODO: بعداً پخش ویدیو با video_player
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.videocam, color: Colors.white70, size: 80),
            SizedBox(height: 16),
            Text('ویدیو', style: TextStyle(color: Colors.white70, fontSize: 18)),
          ],
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorWidget: (context, url, error) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white, size: 80),
      ),
    );
  }

  // چند رسانه → carousel افقی
  return CarouselSlider(
    options: CarouselOptions(
      height: double.infinity,
      viewportFraction: 1.0,
      enlargeCenterPage: false,
      enableInfiniteScroll: mediaItems.length > 1,
      autoPlay: false,
      scrollDirection: Axis.horizontal,
    ),
    items: mediaItems.map((media) {
      final mediaUrl = ApiService().getFullMediaUrl(media.url);

      if (media.mediaType == 'video') {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.videocam, color: Colors.white70, size: 80),
              SizedBox(height: 16),
              Text('ویدیو', style: TextStyle(color: Colors.white70, fontSize: 18)),
            ],
          ),
        );
      }

      return CachedNetworkImage(
        imageUrl: mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 80),
        ),
      );
    }).toList(),
  );
}
  Widget _buildActionButton({
    required IconData icon,
    required dynamic count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _toggleLike(Attraction attraction) {
    // TODO: درخواست POST به /like/
    setState(() {
      // attraction.likeCount++; // فقط برای نمایش موقت
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لایک ثبت شد')),
    );
  }

  void _showCommentsBottomSheet(Attraction attraction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                const Text('کامنت‌ها', style: TextStyle(color: Colors.white, fontSize: 20)),
                ...attraction.comments.map((c) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(c.user, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(c.text, style: const TextStyle(color: Colors.white70)),
                    )),
                // فرم ارسال کامنت جدید
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'کامنت بنویسید...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: () {
                          // TODO: POST کامنت جدید
                        },
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRatingDialog(Attraction attraction) {
    int selectedRating = 5;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('امتیاز بدهید', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < selectedRating ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              onPressed: () {
                setState(() => selectedRating = index + 1);
              },
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              // TODO: POST امتیاز به /rate/
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('امتیاز $selectedRating ثبت شد')),
              );
            },
            child: const Text('ثبت', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}