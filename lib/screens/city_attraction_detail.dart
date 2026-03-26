import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/city.dart'; // Attraction و BaseMedia
import '../services/api_service.dart';
import 'advanced_video_player.dart'; // → VideoPlayerScreen با better_player

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
  final TextEditingController commentController = TextEditingController();



  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _attractionsFuture = _apiService.getAttractions(widget.cityId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attractionsFuture.then((attractions) {
        final initialIndex = attractions.indexWhere((a) => a.id == widget.initialAttractionId);
        if (initialIndex != -1) {
          _pageController.jumpToPage(initialIndex);
          debugPrint("پرش به جاذبه اولیه: ایندکس $initialIndex");
        }
      }).catchError((e) {
        debugPrint("خطا در لود جاذبه‌ها: $e");
      });
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
            return Center(
              child: Text(
                'خطا در بارگذاری\n${snapshot.error}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }

          final attractions = snapshot.data ?? [];
          if (attractions.isEmpty) {
            return const Center(child: Text('جاذبه‌ای یافت نشد', style: TextStyle(color: Colors.white70, fontSize: 18)));
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: attractions.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return _buildAttractionPost(attractions[index]);
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
        // رسانه‌ها (عکس/ویدیو)
        if (attraction.mediaItems.isNotEmpty)
          _buildMediaContent(attraction.mediaItems)
        else
          Container(color: Colors.grey[900]),

        // لایه محتوا
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // هدر
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        attraction.name ?? 'بدون نام',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // توضیحات
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Text(
                      attraction.description ?? 'بدون توضیحات',
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

              // نوار اکشن‌ها
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.92)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.favorite,
                      count: attraction.likeCountMutable,
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
                      count: attraction.averageRatingMutable.toStringAsFixed(1),
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
    if (mediaItems.isEmpty) return Container(color: Colors.grey[900]);

    // تک رسانه
    if (mediaItems.length == 1) {
      final media = mediaItems.first;
      final url = _apiService.getFullMediaUrl(media.url) ?? '';

      if (url.isEmpty) {
        return const Center(child: Icon(Icons.broken_image, color: Colors.white70, size: 80));
      }

      if (media.mediaType == 'video') {
        return VideoPlayerScreen(
          videoUrl: url,
          isMini: false,
        );
      }

      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white70, size: 80)),
      );
    }

    // چند رسانه → Carousel با کنترل پخش فقط visible
    int currentCarouselIndex = 0;

    return StatefulBuilder(
      builder: (context, setCarouselState) {
        return CarouselSlider.builder(
          itemCount: mediaItems.length,
          options: CarouselOptions(
            height: double.infinity,
            viewportFraction: 1.0,
            enlargeCenterPage: false,
            enableInfiniteScroll: mediaItems.length > 1,
            autoPlay: false,
            scrollDirection: Axis.horizontal,
            onPageChanged: (index, reason) {
              setCarouselState(() => currentCarouselIndex = index);
              // نکته: اگر GlobalKey داشتی، اینجا می‌تونی pause/play کنی
              // فعلاً چون ساده نگه داشتیم، پخش خودکار در VideoPlayerScreen فعاله
              // برای پیشرفته‌تر بعداً GlobalKey اضافه می‌کنیم
            },
          ),
          itemBuilder: (context, index, realIndex) {
            final media = mediaItems[index];
            final url = _apiService.getFullMediaUrl(media.url) ?? '';

            if (url.isEmpty) {
              return const Center(child: Icon(Icons.broken_image, color: Colors.white70));
            }

            if (media.mediaType == 'video') {
              // فقط اگر این ایندکس فعلی باشه، پخش می‌شه (اگر autoPlay داخل VideoPlayerScreen true باشه)
              return VideoPlayerScreen(
                videoUrl: url,
                isMini: false,
              );
            }

            return CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white70, size: 80)),
            );
          },
        );
      },
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _toggleLike(Attraction attraction) async {
    try {
      await _apiService.likeAttraction(widget.cityId, attraction.id);

      setState(() {
        if (attraction.userHasLiked) {
          attraction.userHasLiked = false;
          attraction.likeCountMutable--;
        } else {
          attraction.userHasLiked = true;
          attraction.likeCountMutable++;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در لایک')),
      );
    }
  }


  void _showCommentsBottomSheet(Attraction attraction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('کامنت‌ها', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...attraction.comments.map((c) => ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c.user ?? 'کاربر', style: const TextStyle(color: Colors.white)),
                    subtitle: Text(c.text ?? '', style: const TextStyle(color: Colors.white70)),
                  )),
              const SizedBox(height: 24),
              TextField(
                decoration: InputDecoration(
                  hintText: 'نظر خود را بنویسید...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: () async {
                      final text = commentController.text.trim();
                        if (text.isEmpty) return;

                        try {
                          await _apiService.commentAttraction(widget.cityId, attraction.id, text);

                          setState(() {
                            attraction.comments.add(
                              Comment(
                                id: 0,
                                user: "شما",
                                text: text,
                                createdAt: DateTime.now().toIso8601String(), // ← مشکل حل شد
                              ),
                            );
                          });

                          commentController.clear();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطا در ارسال کامنت')),
                          );
                        }
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRatingDialog(Attraction attraction) {
    int selectedRating = attraction.averageRating.round();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('امتیاز شما', style: TextStyle(color: Colors.white)),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = index + 1),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('لغو', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await _apiService.rateAttraction(widget.cityId, attraction.id, selectedRating);

                      setState(() {
                        attraction.averageRatingMutable = selectedRating.toDouble();
                      });

                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطا در ثبت امتیاز')),
                      );
                    }
                  },
                  child: const Text('ثبت', style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}