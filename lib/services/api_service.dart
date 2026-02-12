// lib/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // فقط برای kDebugMode

import '../models/city.dart'; // مدل شهرت رو import کن

class ApiService {
  // ────────────────────────────────────────────────
  //                  تنظیمات پایه
  // ────────────────────────────────────────────────

  static const String _baseUrl = 'http://192.168.0.145:8000/api/v1/'; // emulator اندروید
  // گزینه‌های دیگر:
  // static const String _baseUrl = 'http://192.168.1.XXX:8000/'; // گوشی واقعی (IP لپ‌تاپ)
  // static const String _baseUrl = 'https://api.yourdomain.com/'; // تولید

  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // اضافه کردن لاگ فقط در حالت توسعه (خیلی مفید برای دیباگ)
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }

    // بعداً می‌تونی interceptor برای توکن اضافه کنی:
    // _dio.interceptors.add(AuthInterceptor());
  }

  // ────────────────────────────────────────────────
  //                  متدهای اصلی
  // ────────────────────────────────────────────────

  /// دریافت لیست شهرها (با امکان فیلتر بر اساس کشور)
  Future<List<City>> getCities({
    int? countryId,
    String? search,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};

      if (countryId != null) {
        queryParameters['country'] = countryId;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParameters['search'] = search; // اگر بک‌اند search پشتیبانی کنه
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
      // اینجا می‌تونی خطاهای رایج رو بهتر مدیریت کنی
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('اتصال به سرور زمان‌بر شد');
      }
      if (e.response != null) {
        throw Exception(
          'خطا از سرور: ${e.response?.statusCode} - ${e.response?.data}',
        );
      }
      throw Exception('خطای شبکه: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره: $e');
    }
  }

  // ────────────────────────────────────────────────
  //           متدهای آینده (برای گسترش پروژه)
  // ────────────────────────────────────────────────

  Future<City> getCityDetail(int cityId) async {
    final response = await _dio.get('cities/$cityId/');
    return City.fromJson(response.data);
  }

  // Future<List<Country>> getCountries() async { ... }

  // Future<void> createCity(Map<String, dynamic> data) async { ... }
}