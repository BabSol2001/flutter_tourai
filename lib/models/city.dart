// lib/models/city.dart

abstract class BaseMedia {
  int get id;
  String get mediaType; // 'image' یا 'video'
  String? get url;
  String? get caption;
}

// مدل شهر
class City {
  final int id;
  final String name;
  final int country;           // id کشور
  final String? countryName;   // برای نمایش (از سریالایزر country_name)
  final bool isActive;
  final String? imageUrl;      // بعداً اضافه می‌کنیم یا از جای دیگه می‌گیریم
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
          .map((item) {
            if (item is Map<String, dynamic>) {
              return CityMedia.fromJson(item);
            }
            return null;
          })
          .whereType<CityMedia>()
          .toList(),
    );
  }
}

// رسانه‌های شهر
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

// رسانه‌های جاذبه
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

// مدل جاذبه
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
  });

  factory Attraction.fromJson(Map<String, dynamic> json) {
    return Attraction(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'بدون نام',
      description: json['description'] as String? ?? 'بدون توضیحات',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      likeCount: json['like_count'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,

      mediaItems: (json['media_items'] as List<dynamic>? ?? [])
          .map((item) {
            if (item is Map<String, dynamic>) {
              return AttractionMedia.fromJson(item);
            }
            return null;
          })
          .whereType<BaseMedia>()
          .toList(),

      comments: (json['comments'] as List<dynamic>? ?? [])
          .map((item) {
            if (item is Map<String, dynamic>) {
              return Comment.fromJson(item);
            }
            return null;
          })
          .whereType<Comment>()
          .toList(),

      ratings: (json['ratings'] as List<dynamic>? ?? [])
          .map((item) {
            if (item is Map<String, dynamic>) {
              return Rating.fromJson(item);
            }
            return null;
          })
          .whereType<Rating>()
          .toList(),
    );
  }

  @override
  String toString() {
    return 'Attraction(id: $id, name: $name, mediaCount: ${mediaItems.length}, likes: $likeCount, avgRating: $averageRating)';
  }
}

// کامنت
class Comment {
  final int id;
  final String user;
  final String text;
  final String createdAt;

  Comment({
    required this.id,
    required this.user,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int? ?? 0,
      user: json['user'] as String? ?? 'ناشناس',
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  @override
  String toString() => 'Comment(user: $user, text: $text)';
}

// امتیاز (ستاره)
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

  @override
  String toString() => 'Rating(user: $user, value: $value)';
  
}