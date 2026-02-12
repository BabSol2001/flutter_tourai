import 'package:flutter/material.dart';
import 'theme.dart';
import 'settings_screen.dart';
import 'models/city.dart';           // ← مدل شهر با mediaItems

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

  // ثابت کردن دامنه سرور محلی (برای توسعه - بعداً می‌تونی از env بگیری)
  static const String serverBaseUrl = 'http://192.168.0.145:8000';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // لاگ دیباگ برای چک کردن رسانه‌ها (خیلی مفید برای دیباگ)
    print("DEBUG - CityDetailScreen باز شد");
    print("DEBUG - نام شهر: ${widget.city.name}");
    print("DEBUG - ID شهر: ${widget.city.id}");
    print("DEBUG - تعداد رسانه‌ها: ${widget.city.mediaItems.length}");

    if (widget.city.mediaItems.isNotEmpty) {
      print("DEBUG - لیست رسانه‌ها:");
      for (var i = 0; i < widget.city.mediaItems.length; i++) {
        final m = widget.city.mediaItems[i];
        print("   رسانه ${i + 1}:");
        print("      نوع: ${m.mediaType}");
        print("      URL: ${m.url ?? 'null'}");
        print("      کپشن: ${m.caption ?? 'بدون کپشن'}");
        print("      order: ${m.order}");
        print("      ---");
      }
    } else {
      print("DEBUG - هیچ رسانه‌ای برای این شهر وجود ندارد");
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
            expandedHeight: size.height * 0.4,
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
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // انتخاب عکس پس‌زمینه (جدیدترین عکس معتبر)
                  Builder(
                    builder: (context) {
                      // پیدا کردن آخرین عکس معتبر (جدیدترین آپلود شده)
                      CityMedia? imageMedia;
                      for (final m in widget.city.mediaItems.reversed) {
                        if (m.mediaType == 'image' && m.url != null && m.url!.isNotEmpty) {
                          imageMedia = m;
                          break;
                        }
                      }

                      final rawUrl = imageMedia?.url;
                      final bgUrl = rawUrl != null && rawUrl.isNotEmpty
                          ? '$serverBaseUrl$rawUrl'
                          : 'assets/images/default_background.jpg';

                      print("DEBUG - URL خام از API برای بک‌گراند: $rawUrl");
                      print("DEBUG - URL نهایی بک‌گراند: $bgUrl");

                      return Image(
                        image: bgUrl.startsWith('assets/')
                            ? const AssetImage('assets/images/default_background.jpg')
                            : NetworkImage(bgUrl),
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
                  // تب‌ها
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
                      tabs: const [
                        Tab(text: 'جاذبه‌ها'),
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
          children: [
            _buildAttractionsTab(theme, isTablet),
            _buildStoriesTab(context, theme, isTablet),
            _buildFoodTab(theme, isTablet),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // تب‌ها و کارت‌ها تقریباً بدون تغییر (فعلاً هاردکد هستند)
  // ────────────────────────────────────────────────

  Widget _buildAttractionsTab(ThemeData theme, bool isTablet) {
    final attractions = [
      {
        'name': 'برج ایفل',
        'image': 'https://images.unsplash.com/photo-1516542077187-61520f3bf633?auto=format&fit=crop&w=500&q=80'
      },
      {
        'name': 'موزه لوور',
        'image': 'https://images.unsplash.com/photo-1527004013197-933c4bb611b3?auto=format&fit=crop&w=500&q=80'
      },
      {
        'name': 'کلیسای نوتردام',
        'image': 'https://images.unsplash.com/photo-1551808520-0e2a6f8e8f6f?auto=format&fit=crop&w=500&q=80'
      },
      {
        'name': 'رود سن',
        'image': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=500&q=80'
      },
    ];

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
        final attr = attractions[index];
        return _buildAttractionCard(attr, theme);
      },
    );
  }

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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            trailing: Text(
              food['price'] ?? 'نامشخص',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttractionCard(Map<String, String> attr, ThemeData theme) {
    final textColor = theme.textTheme.bodyMedium?.color;

    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              attr['image']!,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  color: Colors.grey.withOpacity(0.2),
                  child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              attr['name']!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor?.withOpacity(0.7),
            fontSize: 13,
          ),
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