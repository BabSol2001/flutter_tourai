import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io'; // برای کار با شیء File
import 'add_attraction_sheet.dart';
import 'package:image_picker/image_picker.dart'; // برای انتخاب عکس
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/services.dart'; // برای دسترسی به Clipboard
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
  int? _replyingToId;
  String? _replyingToName;
  final FocusNode _commentFocusNode = FocusNode();
  late Future<void> _initProjectFuture;
  late Future<Attraction> _currentDetailFuture;
  final ApiService _apiService = ApiService();
  late PageController _pageController;
  final TextEditingController commentController = TextEditingController();
  File? _selectedImage; // عکسی که کاربر انتخاب کرده
  final ImagePicker _picker = ImagePicker(); // ابزار انتخاب عکس

  int _currentPage = 0;
  List<Attraction> _attractionsList = [];
  bool _descExpanded = false;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // ************ تیکه‌ی جدید (Sorted Comments) ************
  // این گِتِر رو اینجا اضافه کن
  List<Comment> get _sortedComments {
    // چون PageView داریم، باید کامنت‌های جاذبه‌ای که الان کاربر داره میبینه رو بگیریم
    if (_attractionsList.isEmpty) return [];
    
    final currentAttraction = _attractionsList[_currentPage];
    
    // ۱. جدا کردن کامنت‌های اصلی (آنهایی که پدر ندارند)
    final mainComments = currentAttraction.comments.where((c) => c.parent == null).toList();
    final List<Comment> sorted = [];

    for (var parent in mainComments) {
      sorted.add(parent); // اضافه کردن پدر
      
      // ۲. پیدا کردن فرزندان (ریپلای‌ها) برای این پدر خاص
      final replies = currentAttraction.comments.where((c) => c.parent == parent.id).toList();
      sorted.addAll(replies); // اضافه کردن فرزندان بلافاصله زیر پدر
    }
    return sorted;
  }
  // ******************************************************
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

  Future<void> _submitNewAttraction(String name, String desc) async {
    if (name.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لطفاً همه فیلدها را پر کنید')));
      return;
    }

    // نمایش حالت لودینگ
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      // در فایل ApiService باید متد createAttraction را بسازی
      await _apiService.createAttraction(
        cityId: widget.cityId,
        name: name,
        description: desc,
        // فعلاً فایل را خالی می‌فرستیم تا در قدم بعد Picker را وصل کنیم
      );

      if (mounted) {
        Navigator.pop(context); // بستن لودینگ
        Navigator.pop(context); // بستن دیالوگ فرم
        _initializeData(); // رفرش کردن لیست جاذبه‌ها
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاذبه با موفقیت اضافه شد')));
      }
    } catch (e) {
      Navigator.pop(context); // بستن لودینگ
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطا در ثبت اطلاعات')));
    }
  }

  void _showAddAttractionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddAttractionSheet(
        cityId: widget.cityId,
        onUploadSuccess: () {
          // اینجا لیست رو رفرش می‌کنی
        },
      ),
    );
  }

  // ویجت کمکی برای فیلدها
  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      floatingActionButton: Tooltip(
        message: 'اضافه کردن جاذبه جدید', // متنی که می‌خواهی ظاهر شود
        verticalOffset: 48, // فاصله از دکمه که روی دست کاربر نیفتد
        preferBelow: false, // افتادن متن بالای دکمه (چون پایین صفحه است) 
        child: FloatingActionButton(
          backgroundColor: Colors.blueAccent,
          elevation: 4, // کمی سایه برای حس بهتر
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            // باز کردن صفحه یا دیالوگ برای افزودن جاذبه جدید
            _showAddAttractionDialog(); 
          },
        ),
      ),
      // قرار دادن دکمه در سمت چپ下 (برای تداخل نداشتن با ActionBar سمت راست)
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat, 

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

  Future<void> _handleDeleteComment(int commentId, StateSetter setSheetState) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('حذف دیدگاه', style: TextStyle(color: Colors.white)),
        content: const Text('آیا از حذف این دیدگاه اطمینان دارید؟', 
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // ۱. ذخیره یک کپی از کامنت‌ها برای حالت خطا (Rollback)
      final attraction = _attractionsList[_currentPage];
      final List<Comment> backupComments = List.from(attraction.comments);

      // ۲. حذف آنی از حافظه و آپدیت UI (قبل از ارسال به سرور)
      setState(() {
        attraction.comments.removeWhere((c) => c.id == commentId);
      });
      
      // آپدیت کردن لیست داخل شیت به صورت لحظه‌ای
      setSheetState(() {});

      try {
        // ۳. ارسال درخواست حذف به سرور
        await _apiService.deleteComment(widget.cityId, attraction.id, commentId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('دیدگاه با موفقیت حذف شد'))
        );
      } catch (e) {
        // ۴. در صورت خطا، لیست را به حالت قبل برگردان
        setState(() {
          attraction.comments.clear();
          attraction.comments.addAll(backupComments);
        });
        setSheetState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در حذف؛ دوباره تلاش کنید'))
        );
      }
    }
  }

  Future<void> _refreshComments() async {
    try {
      final updatedAttraction = await _apiService.getAttractionDetail(
        widget.cityId, 
        _attractionsList[_currentPage].id
      );

      setState(() {
        // به جای مساوی قرار دادن، محتوا رو بروزرسانی کن
        _attractionsList[_currentPage].comments.clear();
        _attractionsList[_currentPage].comments.addAll(updatedAttraction.comments);
        
        // اگر فیلدهای دیگه هم داری که ممکنه تغییر کرده باشن (مثل Like count)
        // اونا رو هم اینجا دستی آپدیت کن
      });
    } catch (e) {
      debugPrint("خطا در به‌روزرسانی: $e");
    }
  }

  Future<void> _handleTogglePin(Comment comment, StateSetter setSheetState) async {
    final attraction = _attractionsList[_currentPage];
    
    // ۱. تغییر وضعیت بصری به صورت آنی
    setState(() {
      final attraction = _attractionsList[_currentPage];
      for (int i = 0; i < attraction.comments.length; i++) {
        if (attraction.comments[i].id == comment.id) {
          // جایگزین کردن کامنت قدیمی با یک نسخه جدید که پین شده
          attraction.comments[i] = attraction.comments[i].copyWith(
            isPinned: !attraction.comments[i].isPinned
          );
        } else {
          // اگر فقط یک پین مجاز است، بقیه را false کن
          attraction.comments[i] = attraction.comments[i].copyWith(isPinned: false);
        }
      }
    });

    try {
      // ۲. ارسال به سرور
      await _apiService.togglePinComment(widget.cityId, attraction.id, comment.id);
      
      // ۲. گرفتن دیتای جدید از سرور (برای اطمینان از ترتیب و وضعیت پین بقیه کامنت‌ها)
      final updatedAttraction = await _apiService.getAttractionDetail(
        widget.cityId, 
        _attractionsList[_currentPage].id
      );

      // ۳. آپدیت کردن وضعیت کل اپلیکیشن و محیط داخل BottomSheet
      setState(() {
        _attractionsList[_currentPage] = updatedAttraction;
      });
      
      // این خط باعث می‌شه لیستِ داخل شیت بلافاصله بر اساس دیتای جدید (و گتر sorted) دوباره رندر بشه
      setSheetState(() {}); 

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وضعیت سنجاق به‌روزرسانی شد'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطا در تغییر وضعیت سنجاق')));
    }
  }

  // این متد را جایگزین متد قبلی در فایل city_attraction_detail.dart کن
  Widget _buildCommentsSheet(Attraction attraction) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        // اضافه کردن StatefulBuilder برای آپدیت شدن داخل شیت
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            // استفاده از لیست مرتب شده برای نمایش درست ریپلای‌ها
            final commentsList = _sortedComments; 

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  _buildHandle(), // نوار کوچک بالای شیت
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('دیدگاه‌ها', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  
                  // لیست دیدگاه‌ها
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: commentsList.length,
                      itemBuilder: (context, index) {
                        final c = commentsList[index];
                        final isReply = c.parent != null;

                        return Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: isReply ? 58.0 : 16.0, 
                            end: 16.0,
                            top: 10.0,
                            bottom: 10.0,
                          ),
                          child: _buildCommentTile(c, isReply, setSheetState),
                        );
                      },
                    ),
                  ),

                  // بخش ورودی متن و انتخاب عکس
                  _buildEnhancedInputArea(attraction),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // متد کمکی برای بخش ورودی (با قابلیت پیش‌نمایش عکس و لغو پاسخ)
  Widget _buildEnhancedInputArea(Attraction attraction) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // نمایش وضعیت پاسخ به دیگران
          if (_replyingToId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Text('پاسخ به $_replyingToName', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() { _replyingToId = null; _replyingToName = null; commentController.clear(); }),
                    child: const Icon(Icons.cancel, color: Colors.white54, size: 16),
                  ),
                ],
              ),
            ),
          
          // پیش‌نمایش عکس انتخاب شده
          if (_selectedImage != null)
            Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 60, width: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  right: -5, top: -5,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImage = null),
                    child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                  ),
                ),
              ],
            ),

          Row(
            children: [
              IconButton(
                icon: Icon(Icons.image, color: _selectedImage != null ? Colors.blue : Colors.white54),
                onPressed: _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: commentController,
                  focusNode: _commentFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'نظر خود را بنویسید...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () => _handleSendComment(attraction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // منطق ارسال کامنت
  Future<void> _handleSendComment(Attraction attraction) async {
    final text = commentController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    try {
      await _apiService.commentAttraction(
        widget.cityId,
        attraction.id,
        text,
        parentId: _replyingToId,
        imagePath: _selectedImage?.path, // این خط اضافه شود
      );

      setState(() {
        attraction.comments.add(Comment(
          id: DateTime.now().millisecondsSinceEpoch,
          user: "شما",
          text: text,
          parent: _replyingToId,
          createdAt: DateTime.now().toIso8601String(),
        ));
        _selectedImage = null;
        _replyingToId = null;
        commentController.clear();
      });
      _commentFocusNode.unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطا در ارسال')));
    }
  }

  void _showCommentOptions(Comment comment, StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, // به اندازه محتوا باز شود
            children: [
              _buildHandle(), // همان نوار کوچک بالای شیت
              
              // گزینه کپی متن (مثال برای قابلیت‌های آینده)
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white70),
                title: const Text('کپی متن دیدگاه', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  // ۱. کپی کردن متن در حافظه گوشی
                  await Clipboard.setData(ClipboardData(text: comment.text ?? ""));
                  // ۲. بستن منوی BottomSheet
                  if (context.mounted) Navigator.pop(context);
                  
                  // ۳. اطلاع‌رسانی به کاربر با یک SnackBar ساده
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('متن دیدگاه کپی شد'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating, // برای ظاهر شکیل‌تر
                      ),
                    );
                  }
                },
              ),

              // گزینه حذف (فقط برای صاحب کامنت یا مدیر)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('حذف دیدگاه', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context); // بستن منو
                  _handleDeleteComment(comment.id, setSheetState); // اجرای حذف
                },
              ),
              
              ListTile(
                leading: Icon(
                  comment.isPinned ? Icons.push_pin : Icons.push_pin_outlined, 
                  color: comment.isPinned ? Colors.amber : Colors.white70
                ),
                title: Text(
                  comment.isPinned ? 'برداشتن پین' : 'سنجاق کردن (Pin)',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context); // بستن منو
                  await _handleTogglePin(comment, setSheetState);
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentTile(Comment c, bool isReply, StateSetter setSheetState) {
  return GestureDetector(
    // با نگه داشتن انگشت، منوی عملیات باز می‌شود
    onLongPress: () => _showCommentOptions(c, setSheetState),
    child: Container(
      // یک رنگ پس‌زمینه شفاف می‌دهیم تا کل فضای تایل قابل لمس باشد
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.user, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (c.isPinned) ...[
              const SizedBox(width: 8),
              const Icon(Icons.push_pin_sharp, size: 18, color: Colors.amber),
              //const Text("سنجاق شده", style: TextStyle(fontSize: 10, color: Colors.amber)),
            ],
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundColor: Colors.white10,
            child: Icon(Icons.person, color: Colors.white70, size: isReply ? 16 : 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    children: [
                      TextSpan(text: '${c.user ?? 'کاربر'} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: c.text ?? '', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _replyingToId = c.id;
                      _replyingToName = c.user;
                      commentController.text = '@${c.user} ';
                    });
                    _commentFocusNode.requestFocus();
                  },
                  child: const Text(
                    'پاسخ', 
                    style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildHandle() => Container(
    width: 40, 
    height: 4, 
    margin: const EdgeInsets.symmetric(vertical: 12), 
    decoration: BoxDecoration(
      color: Colors.white24, 
      borderRadius: BorderRadius.circular(10)
    )
  );

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
