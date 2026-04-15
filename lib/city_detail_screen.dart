import 'package:flutter/material.dart';
import 'package:flutter_tourai/theme.dart';
import 'package:flutter_tourai/settings_screen.dart';
import 'package:flutter_tourai/models/city.dart';
import 'package:flutter_tourai/screens/media_gallery_screen.dart';
import 'package:flutter_tourai/screens/city_attraction_detail.dart';
import 'package:flutter_tourai/services/api_service.dart';
import './screens/city_live_detail.dart'; // فایل تب لایو
import './screens/add_attraction_sheet.dart';//برای اضافه کردن یک جاذبه جدید
class CityDetailScreen extends StatefulWidget {
  final City city;

  const CityDetailScreen({
    super.key,
    required this.city,
  });

  @override
  State<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends State<CityDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ApiService _apiService;
  late Future<List<Attraction>> _attractionsFuture;
  late Future<List<Live>> _livesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _apiService = ApiService();

    _attractionsFuture = _apiService.getAttractions(widget.city.id);
    _livesFuture = _apiService.getLives(widget.city.id);

    // لاگ رسانه‌ها (بدون تغییر)
    print("DEBUG - CityDetailScreen باز شد");
    print("DEBUG - نام شهر: ${widget.city.name}");
    print("DEBUG - ID شهر: ${widget.city.id}");
    print("DEBUG - تعداد رسانه‌ها: ${widget.city.mediaItems.length}");

    if (widget.city.mediaItems.isNotEmpty) {
      print("DEBUG - لیست رسانه‌ها:");
      for (var i = 0; i < widget.city.mediaItems.length; i++) {
        final m = widget.city.mediaItems[i];
        print("   رسانه ${i + 1}: نوع=${m.mediaType} | URL=${m.url ?? 'null'} | کپشن=${m.caption ?? 'بدون کپشن'}");
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: size.height * (isTablet ? 0.35 : 0.4),
            floating: false,
            pinned: true,
            backgroundColor: theme.appBarTheme.backgroundColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: theme.appBarTheme.foregroundColor),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: theme.appBarTheme.foregroundColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) {
                  if (value == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(
                          isDarkMode: theme.brightness == Brightness.dark,
                          onThemeChanged: (v) {},
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(children: [Icon(Icons.settings), SizedBox(width: 12), Text('تنظیمات')]),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.city.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: theme.appBarTheme.foregroundColor,
                ),
              ),
              background: GestureDetector(
                onTap: () {
                  if (widget.city.mediaItems.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MediaGalleryScreen(
                          mediaItems: widget.city.mediaItems,
                          initialIndex: 0,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('رسانه‌ای برای نمایش وجود ندارد')),
                    );
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Builder(
                      builder: (context) {
                        CityMedia? imageMedia;
                        for (final m in widget.city.mediaItems.reversed) {
                          if (m.mediaType == 'image' && m.url != null && m.url!.trim().isNotEmpty) {
                            imageMedia = m;
                            break;
                          }
                        }

                        final bgUrl = _apiService.getFullMediaUrl(imageMedia?.url ?? '');

                        print("DEBUG - URL نهایی بک‌گراند: $bgUrl");

                        return Image(
                          image: bgUrl.isNotEmpty && !bgUrl.startsWith('assets/')
                              ? NetworkImage(bgUrl)
                              : const AssetImage('assets/images/default_background.jpg'),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print("ERROR - لود بک‌گراند شکست خورد: $error");
                            return Container(
                              color: Colors.grey[400],
                              child: const Icon(Icons.broken_image, size: 80),
                            );
                          },
                        );
                      },
                    ),

                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.city.description ?? 'توضیحاتی برای این شهر موجود نیست',
                    style: TextStyle(fontSize: 16, color: textColor?.withOpacity(0.9)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        widget.city.rating?.toStringAsFixed(1) ?? '—',
                        style: TextStyle(fontSize: 16, color: textColor),
                      ),
                      const Spacer(),
                      Text(
                        widget.city.price ?? 'قیمت موجود نیست',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppTheme.primary,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: textColor?.withOpacity(0.6),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: 'جاذبه‌ها'),
                        Tab(text: 'لایو'),
                        Tab(text: 'داستان‌ها'),
                        Tab(text: 'غذا'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(), // اسکرول نرم‌تر بین تب‌ها
          children: [
            _buildAttractionsTab(theme, isTablet),
            _buildLiveTab(),
            _buildStoriesTab(context, theme, isTablet),
            _buildFoodTab(theme, isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildAttractionsTab(ThemeData theme, bool isTablet) {
    // استفاده از استک برای قرار دادن دکمه روی لیست
    return Stack (
      children: [
        FutureBuilder<List<Attraction>>(
          future: _attractionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('خطا در بارگذاری جاذبه‌ها: ${snapshot.error.toString().split('\n').first}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _attractionsFuture = _apiService.getAttractions(widget.city.id);
                        });
                      },
                      child: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              );
            }

            final attractions = snapshot.data ?? [];

            if (attractions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_city_outlined, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('هنوز جاذبه‌ای برای این شهر ثبت نشده', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: attractions.length,
              itemBuilder: (context, index) {
                final attraction = attractions[index];
                return _buildAttractionCard(attraction, theme);
              },
            );
          },
        ),
        // دکمه شناور روی تب
        Positioned(
          bottom: 20,
          left: 20,
          child: Tooltip(
            message: 'اضافه کردن جاذبه جدید',
            verticalOffset: 48,
            preferBelow: false,
            child: FloatingActionButton(
              backgroundColor: Colors.blueAccent,
              elevation: 4,
              onPressed: _showAddAttractionDialog,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ]
    );
  }

  void _showAddAttractionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // برای اینکه کیبورد روی فیلدها را نپوشاند
      backgroundColor: Colors.transparent,
      builder: (context) => AddAttractionSheet(
        cityId: widget.city.id, // آیدی شهر را به شیت پاس می‌دهیم
        onUploadSuccess: () {
          // بعد از آپلود موفق، لیست را رفرش می‌کنیم
          setState(() {
            _attractionsFuture = _apiService.getAttractions(widget.city.id);
          });
        },
      ),
    );
  }

  Widget _buildLiveTab() {
    return CityLiveTab(cityId: widget.city.id, livesFuture: _livesFuture);
  }

  // بقیه متدها (بدون تغییر بزرگ، فقط بهبود کوچک)
  Widget _buildAttractionCard(Attraction attraction, ThemeData theme) {
    final textColor = theme.textTheme.bodyMedium?.color;

    String imageUrl = 'assets/images/default_attraction.jpg';
    for (final media in attraction.mediaItems) {
      if (media.url != null && media.url!.trim().isNotEmpty) {
        imageUrl = _apiService.getFullMediaUrl(media.url!);
        break;
      }
    }

    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CityAttractionDetailScreen(
                cityId: widget.city.id,
                initialAttractionId: attraction.id,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint("ERROR - لود عکس جاذبه ${attraction.name} شکست خورد: $error");
                  return Container(
                    height: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attraction.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attraction.description.length > 60
                        ? '${attraction.description.substring(0, 60)}...'
                        : attraction.description,
                    style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(' ${attraction.averageRating.toStringAsFixed(1)}'),
                      const Spacer(),
                      Text('${attraction.likeCount} لایک'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تب داستان‌ها و غذا (بدون تغییر بزرگ)
  Widget _buildStoriesTab(BuildContext context, ThemeData theme, bool isTablet) {
    final textColor = theme.textTheme.bodyMedium?.color;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStoryItem(context, 'داستان عشق در پاریس', 'در سال ۱۸۸۹، یک نقاش جوان عاشق یک دختر فرانسوی شد...', theme, textColor),
        _buildStoryItem(context, 'راز برج ایفل', 'آیا می‌دانستید که برج ایفل در ابتدا قرار بود فقط ۲۰ سال بماند؟', theme, textColor),
        _buildStoryItem(context, 'شب‌های مونمارتر', 'کافه‌های قدیمی و هنرمندان خیابانی...', theme, textColor),
      ],
    );
  }

  Widget _buildFoodTab(ThemeData theme, bool isTablet) {
    final foods = [
      {'name': 'کروسان', 'price': '۸۰,۰۰۰ تومان'},
      {'name': 'اسکارگو', 'price': '۲۵۰,۰۰۰ تومان'},
      {'name': 'راتاتویی', 'price': '۱۸۰,۰۰۰ تومان'},
      {'name': 'کرپ', 'price': '۱۲۰,۰۰۰ تومان'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        final textColor = theme.textTheme.bodyMedium?.color;
        return Card(
          elevation: 0,
          color: theme.cardTheme.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.2),
              child: Icon(Icons.restaurant, color: AppTheme.primary),
            ),
            title: Text(
              food['name'] ?? 'نامشخص',
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            trailing: Text(
              food['price'] ?? 'نامشخص',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoryItem(BuildContext context, String title, String subtitle, ThemeData theme, Color? textColor) {
    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.2),
          child: Icon(Icons.menu_book, color: AppTheme.primary),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 13),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: textColor?.withOpacity(0.5),
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('داستان: $title')),
          );
        },
      ),
    );
  }
}