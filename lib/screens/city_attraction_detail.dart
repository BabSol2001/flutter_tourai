import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/city.dart';
import '../services/api_service.dart';
import 'advanced_video_player.dart';

class CityAttractionDetailScreen extends StatefulWidget {
  final int cityId;
  final int initialAttractionId;

  const CityAttractionDetailScreen({
    super.key,
    required this.cityId,
    required this.initialAttractionId,
  });

  @override
  State<CityAttractionDetailScreen> createState() =>
      _CityAttractionDetailScreenState();
}

class _CityAttractionDetailScreenState extends State<CityAttractionDetailScreen> {
  // این فیوچر حالا هم لیست رو میگیره هم ایندکس شروع رو حساب میکنه
  late Future<void> _initProjectFuture;
  
  late Future<Attraction> _currentDetailFuture;
  final ApiService _apiService = ApiService();
  
  // کنترلر رو لیت (late) تعریف میکنیم تا بتونیم با ایندکس درست بسازیمش
  late PageController _pageController;
  final TextEditingController commentController = TextEditingController();

  int _currentPage = 0;
  List<Attraction> _attractionsList = [];
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    _initProjectFuture = _initializeData();
  }

  // --- قدم اول: آماده‌سازی داده‌ها قبل از نمایش ---
  Future<void> _initializeData() async {
    // ۱. گرفتن لیست همه جاذبه‌ها
    final list = await _apiService.getAttractions(widget.cityId);
    
    // ۲. مرتب‌سازی بر اساس ID (برای اینکه بالا و پایین رفتن ترتیب داشته باشه)
    list.sort((a, b) => a.id.compareTo(b.id));
    
    // ۳. پیدا کردن جایگاه (index) جاذبه‌ای که کاربر انتخاب کرده
    int startIndex = list.indexWhere((attr) => attr.id == widget.initialAttractionId);
    if (startIndex == -1) startIndex = 0;

    setState(() {
      _attractionsList = list;
      _currentPage = startIndex;
      // ساخت کنترلر با صفحه شروع درست
      _pageController = PageController(initialPage: startIndex);
      
      // لود جزئیات کامل اولین جاذبه
      _currentDetailFuture = _apiService.getAttractionDetail(
        widget.cityId,
        _attractionsList[_currentPage].id,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // از یک FutureBuilder کلی برای لود اولیه استفاده میکنیم
      body: FutureBuilder(
        future: _initProjectFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (_attractionsList.isEmpty) {
            return const Center(child: Text('جاذبه‌ای یافت نشد', style: TextStyle(color: Colors.white)));
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical, // سوییپ عمودی (مثل تیک‌تاک)
            physics: const BouncingScrollPhysics(), // حالت ارتجاعی در ابتدا و انتها
            itemCount: _attractionsList.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _descExpanded = false; // بستن توضیحات وقتی صفحه عوض میشه
                
                // درخواست به سرور برای گرفتن جزئیات کامل (لایک، کامنت و ...) جاذبه جدید
                _currentDetailFuture = _apiService.getAttractionDetail(
                  widget.cityId,
                  _attractionsList[index].id,
                );
              });
            },
            itemBuilder: (context, index) {
              // برای صفحه‌ای که الان کاربر داره میبینه، منتظر جزئیات کامل می‌مونیم
              if (index == _currentPage) {
                return FutureBuilder<Attraction>(
                  future: _currentDetailFuture,
                  builder: (context, detailSnapshot) {
                    if (detailSnapshot.hasData) {
                      return _buildAttraction(detailSnapshot.data!);
                    }
                    // تا وقتی لود بشه، ظاهر کلی رو با دیتای لیست نشون بده
                    return _buildAttraction(_attractionsList[index]);
                  },
                );
              }
              // برای بقیه صفحات (پیش‌نمایش)
              return _buildAttraction(_attractionsList[index]);
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // بقیه متدها مثل _buildAttraction و ... بدون تغییر نسبت به کد خودت
  // فقط مطمئن شو که همه رو کپی کردی
  // ---------------------------------------------------------------------------

  Widget _buildAttraction(Attraction attraction) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMediaContent(attraction.mediaItems),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(attraction),
              const Spacer(),
              _buildDescription(attraction),
              _buildActionBar(attraction),
            ],
          ),
        ),
      ],
    );
  }

  // متدهای Header, Description, ActionBar و Media Content رو از کد خودت اینجا اضافه کن...
  // (برای کوتاه شدن پاسخ، بقیه متدها رو تکرار نکردم ولی دقیقا مثل کد خودته)

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(Attraction attraction) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                attraction.name ?? 'بدون نام',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESCRIPTION
  // ---------------------------------------------------------------------------

  Widget _buildDescription(Attraction attraction) {
    final text = attraction.description ?? 'بدون توضیحات';

    return GestureDetector(
      onTap: () {
        setState(() => _descExpanded = !_descExpanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxHeight: _descExpanded ? 140 : 28,
        ),
        child: SingleChildScrollView(
          primary: false,
          physics: _descExpanded
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
            maxLines: _descExpanded ? 10 : 1,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION BAR
  // ---------------------------------------------------------------------------

  Widget _buildActionBar(Attraction attraction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.favorite,
            count: attraction.likeCountMutable,
            color: Colors.redAccent,
            onTap: () => _toggleLike(attraction),
          ),
          _buildActionButton(
            icon: Icons.comment,
            count: attraction.comments.length,
            color: Colors.blueAccent,
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MEDIA (Carousel + Video)
  // ---------------------------------------------------------------------------

  Widget _buildMediaContent(List<BaseMedia> mediaItems) {
    if (mediaItems.isEmpty) return Container(color: Colors.grey[900]);

    int currentIndex = 0;

    return StatefulBuilder(
      builder: (context, setState) {
        return Stack(
          children: [
            CarouselSlider.builder(
              itemCount: mediaItems.length,
              options: CarouselOptions(
                height: double.infinity,
                viewportFraction: 1.0,
                enableInfiniteScroll: mediaItems.length > 1,
                scrollDirection: Axis.horizontal,
                // اگر حس کردی تداخل با سوییپ عمودی هست، این خط را فعال کن:
                // scrollPhysics: const PageScrollPhysics(),
                onPageChanged: (i, _) => setState(() => currentIndex = i),
              ),
              itemBuilder: (context, index, _) {
                final media = mediaItems[index];
                final url = _apiService.getFullMediaUrl(media.url);

                if (media.mediaType == 'video') {
                  return VideoPlayerScreen(videoUrl: url, isMini: false);
                }

                return CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white70),
                  ),
                );
              },
            ),

            // indicator
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  mediaItems.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: currentIndex == i ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentIndex == i
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // LIKE / COMMENT / RATING
  // ---------------------------------------------------------------------------

  void _toggleLike(Attraction attraction) async {
    try {
      await _apiService.likeAttraction(widget.cityId, attraction.id);

      setState(() {
        attraction.userHasLiked = !attraction.userHasLiked;
        attraction.likeCountMutable += attraction.userHasLiked ? 1 : -1;
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در لایک')),
      );
    }
  }

  void _showCommentsBottomSheet(Attraction attraction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _buildCommentsSheet(attraction),
    );
  }

  Widget _buildCommentsSheet(Attraction attraction) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'کامنت‌ها',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ...attraction.comments.map(
                      (c) => ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.white10,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          c.user ?? 'کاربر',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          c.text ?? '',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: 'نظر خود را بنویسید...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: () async {
                      final text = commentController.text.trim();
                      if (text.isEmpty) return;

                      try {
                        await _apiService.commentAttraction(
                          widget.cityId,
                          attraction.id,
                          text,
                        );

                        setState(() {
                          attraction.comments.add(
                            Comment(
                              id: 0,
                              user: "شما",
                              text: text,
                              createdAt: DateTime.now().toIso8601String(),
                            ),
                          );
                        });

                        commentController.clear();
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('خطا در ارسال کامنت')),
                        );
                      }
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'امتیاز شما',
                style: TextStyle(color: Colors.white),
              ),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'لغو',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await _apiService.rateAttraction(
                        widget.cityId,
                        attraction.id,
                        selectedRating,
                      );

                      setState(() {
                        attraction.averageRatingMutable =
                            selectedRating.toDouble();
                      });

                      Navigator.pop(context);
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('خطا در ثبت امتیاز')),
                      );
                    }
                  },
                  child: const Text(
                    'ثبت',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
