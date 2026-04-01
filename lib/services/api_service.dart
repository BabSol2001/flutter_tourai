// lib/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // برای kDebugMode

import '../models/city.dart'; // شامل City و Attraction

class ApiService {
  // ────────────────────────────────────────────────
  //                  تنظیمات پایه
  // ────────────────────────────────────────────────

  static const String baseUrl = 'http://192.168.0.147:8000/api/v1/';
  
  // دامنه پایه برای فایل‌های رسانه (عکس/ویدیو)
  // فقط همین یک جا رو تغییر بده وقتی سرور عوض شد
  static const String _mediaBaseUrl = 'http://192.168.0.147:8000';

  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // فعال کردن لاگ درخواست‌ها فقط در حالت توسعه
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }
  }

  // ────────────────────────────────────────────────
  //         متد مرکزی برای URL رسانه‌ها
  // ────────────────────────────────────────────────

  /// این متد همه جا استفاده می‌شود تا URL رسانه کامل شود
  /// اگر url نسبی باشد (مثل /media/...) دامنه اضافه می‌کند
  /// اگر کامل باشد (شامل http) همان را برمی‌گرداند
  String getFullMediaUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return 'assets/images/default.jpg';
    }

    // اگر از قبل کامل بود، همان را برگردان
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    // اضافه کردن دامنه به مسیر نسبی
    final cleanPath = relativeUrl.startsWith('/') ? relativeUrl : '/$relativeUrl';
    return '$_mediaBaseUrl$cleanPath';
  }

  // ────────────────────────────────────────────────
  //                  متدهای اصلی API
  // ────────────────────────────────────────────────

  /// دریافت لیست شهرها با فیلترهای اختیاری
  Future<List<City>> getCities({
    int? countryId,
    String? search,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};

      if (countryId != null) queryParameters['country'] = countryId;
      if (search != null && search.trim().isNotEmpty) {
        queryParameters['search'] = search.trim();
      }

      final response = await _dio.get(
        'cities/cities/',
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data;
        return jsonList.map((json) => City.fromJson(json)).toList();
      } else {
        throw Exception('خطا در دریافت شهرها: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      debugPrint('خطای غیرمنتظره در getCities: $e');
      rethrow;
    }
  }

  /// دریافت لیست جاذبه‌های یک شهر خاص
  Future<List<Attraction>> getAttractions(int cityId) async {
    try {
      final response = await _dio.get(
        'cities/cities/$cityId/attractions/',
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;

        if (jsonData is List) {
          return jsonData.map((item) => Attraction.fromJson(item)).toList();
        }

        if (jsonData is Map && jsonData.containsKey('results')) {
          final results = jsonData['results'] as List;
          return results.map((item) => Attraction.fromJson(item)).toList();
        }

        throw Exception('فرمت پاسخ API نامعتبر است');
      } else {
        throw Exception('خطا در لود جاذبه‌ها: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      debugPrint('خطای غیرمنتظره در getAttractions: $e');
      rethrow;
    }
  }

  Future<Attraction> getAttractionDetail(int cityId, int attractionId) async {
    try {
      final response = await _dio.get(
        'cities/cities/$cityId/attractions/$attractionId/',
      );

      if (response.statusCode == 200) {
        return Attraction.fromJson(response.data);
      } else {
        throw Exception('خطا در دریافت جاذبه: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      debugPrint('خطای غیرمنتظره در getAttractionDetail: $e');
      rethrow;
    }
  }



  // ────────────────────────────────────────────────
  //                  متدهای کمکی
  // ────────────────────────────────────────────────

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      debugPrint('اتصال به سرور زمان‌بر شد');
    } else if (e.response != null) {
      debugPrint('خطا از سرور: ${e.response?.statusCode} - ${e.response?.data}');
    } else {
      debugPrint('خطای شبکه: ${e.message}');
    }
  }

  // بعد از متد getAttractions اضافه کن
  Future<List<Live>> getLives(int cityId) async {
    try {
      final response = await _dio.get('cities/cities/$cityId/lives/');

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> list = data is Map && data.containsKey('results')
            ? data['results']
            : data;

        return list.map((item) => Live.fromJson(item)).toList();
      }
      throw Exception('خطا در دریافت لایوها');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  // ------------------------------
// Attraction Like
// ------------------------------
Future<void> likeAttraction(int cityId, int attractionId) async {
  try {
    await _dio.post(
      'cities/cities/$cityId/attractions/$attractionId/like/',
    );
  } catch (e) {
    _handleDioError(e as DioException);
    rethrow;
  }
}

// ------------------------------
// Attraction Comment
// ------------------------------
Future<void> commentAttraction(int cityId, int attractionId, String text) async {
  try {
    await _dio.post(
      'cities/cities/$cityId/attractions/$attractionId/comment/',
      data: {'text': text},
    );

  } catch (e) {
    _handleDioError(e as DioException);
    rethrow;
  }
}

// ------------------------------
// Attraction Rating
// ------------------------------
Future<void> rateAttraction(int cityId, int attractionId, int score) async {
  try {
    await _dio.post(
      'cities/cities/$cityId/attractions/$attractionId/rate/',
      data: {'score': score},
    );

  } catch (e) {
    _handleDioError(e as DioException);
    rethrow;
  }
}



  // می‌تونی متدهای دیگه  رو هم اینجا اضافه کنی
}