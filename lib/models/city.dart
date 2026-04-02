// lib/models/city.dart

abstract class BaseMedia {
  int get id;
  String get mediaType; // 'image' یا 'video'
  String? get url;
  String? get caption;
}

// ─────────────────────────────────────────────
// مدل شهر
// ─────────────────────────────────────────────
class City {
  final int id;
  final String name;
  final int country;
  final String? countryName;
  final bool isActive;
  final String? imageUrl;
  final double? rating;
  final String? price;
  final String? description;
  final String? priceText;
  final int likesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  final List<CityMedia> mediaItems;

  City({
    required this.id,
    required this.name,
    required this.country,
    this.countryName,
    this.isActive = true,
    this.imageUrl,
    this.rating,
    this.price,
    this.description,
    this.priceText,
    this.likesCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.mediaItems = const [],
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'بدون نام',
      country: json['country'] as int? ?? 0,
      countryName: json['country_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      price: json['price'] as String?,
      description: json['description'] as String?,
      priceText: json['price_text'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      mediaItems: (json['media_items'] as List<dynamic>? ?? [])
          .map((item) => item is Map<String, dynamic> ? CityMedia.fromJson(item) : null)
          .whereType<CityMedia>()
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────
// رسانه‌های شهر
// ─────────────────────────────────────────────
class CityMedia implements BaseMedia {
  @override
  final int id;
  @override
  final String mediaType;
  @override
  final String? url;
  @override
  final String? caption;
  final int order;
  final DateTime createdAt;

  CityMedia({
    required this.id,
    required this.mediaType,
    this.url,
    this.caption,
    required this.order,
    required this.createdAt,
  });

  factory CityMedia.fromJson(Map<String, dynamic> json) {
    return CityMedia(
      id: json['id'] as int? ?? 0,
      mediaType: json['media_type'] as String? ?? 'image',
      url: json['url'] as String?,
      caption: json['caption'] as String?,
      order: json['order'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────
// رسانه‌های جاذبه
// ─────────────────────────────────────────────
class AttractionMedia implements BaseMedia {
  @override
  final int id;
  @override
  final String mediaType;
  @override
  final String? url;
  @override
  final String? caption;

  AttractionMedia({
    required this.id,
    required this.mediaType,
    this.url,
    this.caption,
  });

  factory AttractionMedia.fromJson(Map<String, dynamic> json) {
    return AttractionMedia(
      id: json['id'] as int? ?? 0,
      mediaType: json['media_type'] as String? ?? 'image',
      url: json['url'] as String?,
      caption: json['caption'] as String?,
    );
  }
}

// ─────────────────────────────────────────────
// مدل جاذبه (با کمترین تغییر → فقط فیلدهای محلی اضافه شد)
// ─────────────────────────────────────────────
class Attraction {
  final int id;
  final String name;
  final String description;
  final double averageRating;
  final int likeCount;
  final double score;

  final List<BaseMedia> mediaItems;
  final List<Comment> comments;
  final List<Rating> ratings;

  // ── فیلدهای محلی (برای UI) ─────────────────────
  bool userHasLiked;
  int likeCountMutable;
  double averageRatingMutable;

  Attraction({
    required this.id,
    required this.name,
    required this.description,
    required this.averageRating,
    required this.likeCount,
    required this.score,
    required this.mediaItems,
    required this.comments,
    required this.ratings,

    this.userHasLiked = false,
    int? likeCountMutable,
    double? averageRatingMutable,
  })  : likeCountMutable = likeCountMutable ?? likeCount,
        averageRatingMutable = averageRatingMutable ?? averageRating;

  factory Attraction.fromJson(Map<String, dynamic> json) {
    return Attraction(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'بدون نام',
      description: json['description'] as String? ?? 'بدون توضیحات',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      likeCount: json['like_count'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,

      mediaItems: (json['media_items'] as List<dynamic>? ?? [])
          .map((item) => item is Map<String, dynamic> ? AttractionMedia.fromJson(item) : null)
          .whereType<BaseMedia>()
          .toList(),

      comments: (json['comments'] as List<dynamic>? ?? [])
          .map((item) => item is Map<String, dynamic> ? Comment.fromJson(item) : null)
          .whereType<Comment>()
          .toList(),

      ratings: (json['ratings'] as List<dynamic>? ?? [])
          .map((item) => item is Map<String, dynamic> ? Rating.fromJson(item) : null)
          .whereType<Rating>()
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────
// کامنت
// ─────────────────────────────────────────────
class Comment {
  final int id;
  final String user;
  final String text;
  final String createdAt;
  final int? parent; // آیدی کامنت والد
  final List<Comment> replies; // لیست پاسخ‌ها

  Comment({
    required this.id,
    required this.user,
    required this.text,
    required this.createdAt,
    this.parent,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    var repliesFromJson = json['replies'] as List? ?? [];
    List<Comment> repliesList = repliesFromJson.map((i) => Comment.fromJson(i)).toList();
    
    return Comment(
      id: json['id'] as int? ?? 0,
      user: json['user'] as String? ?? 'ناشناس',
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      parent: json['parent'],
      replies: repliesList,
    );
  }
}

// ─────────────────────────────────────────────
// امتیاز
// ─────────────────────────────────────────────
class Rating {
  final int id;
  final String user;
  final int value;

  Rating({
    required this.id,
    required this.user,
    required this.value,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] as int? ?? 0,
      user: json['user'] as String? ?? 'ناشناس',
      value: json['value'] as int? ?? 0,
    );
  }
}

// ─────────────────────────────────────────────
// مدل لایو
// ─────────────────────────────────────────────
class Live {
  final int id;
  final String title;
  final String? description;
  final bool isActive;
  final int viewerCount;
  final String? thumbnailUrl;
  final String? playbackUrl;
  final DateTime? startTime;
  final DateTime createdAt;

  Live({
    required this.id,
    required this.title,
    this.description,
    this.isActive = false,
    this.viewerCount = 0,
    this.thumbnailUrl,
    this.playbackUrl,
    this.startTime,
    required this.createdAt,
  });

  factory Live.fromJson(Map<String, dynamic> json) {
    return Live(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'لایو بدون عنوان',
      description: json['description'],
      isActive: json['is_active'] ?? false,
      viewerCount: json['viewer_count'] ?? 0,
      thumbnailUrl: json['thumbnail_url'],
      playbackUrl: json['playback_url'] ?? json['hls_url'],
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'])
          : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
