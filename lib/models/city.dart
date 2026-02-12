class City {
  final int id;
  final String name;
  final int country;           // id کشور
  final String? countryName;   // برای نمایش (از سریالایزر country_name)
  final bool isActive;
  final String? imageUrl;      // بعداً اضافه می‌کنیم یا از جای دیگه می‌گیریم
  final double? rating;        // اگر اضافه کردی به مدل
  final String? price;         // اگر اضافه کردی
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

  City.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        country = json['country'],
        countryName = json['country_name'],
        imageUrl = json['image_url'],
        rating = (json['rating'] as num?)?.toDouble(),
        price = json['price'],
        description = json['description'],
        priceText = json['price_text'],
        likesCount = json['likes_count'],
        isActive = json['is_active'],
        createdAt = DateTime.parse(json['created_at']),
        updatedAt = DateTime.parse(json['updated_at']),
        mediaItems = (json['media_items'] as List<dynamic>?)
                ?.map((item) => CityMedia.fromJson(item))
                .toList() ??
            [];      
}

class CityMedia {
  final int id;
  final String mediaType; // 'image' یا 'video'
  final String? url;
  final String? caption;
  final int order;
  final DateTime createdAt;

  // constructor معمولی (unnamed) اضافه شد
  CityMedia({
    required this.id,
    required this.mediaType,
    this.url,
    this.caption,
    required this.order,
    required this.createdAt,
  });

  CityMedia.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        mediaType = json['media_type'],
        url = json['url'],
        caption = json['caption'],
        order = json['order'],
        createdAt = DateTime.parse(json['created_at']);
}