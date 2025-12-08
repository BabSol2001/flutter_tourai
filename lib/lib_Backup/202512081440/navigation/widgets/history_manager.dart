// lib/navigation/widget/history_manager.dart

import 'package:shared_preferences/shared_preferences.dart';

/// کلاس مدیریت تاریخچه جستجو
/// وظیفه اصلی: تعامل با SharedPreferences برای ذخیره و بازیابی لیست جستجوها.
class SearchHistoryManager {
  static const String _historyKey = 'searchHistory';
  static const int _maxHistorySize = 10;
  
  // لیست تاریخچه که در حافظه نگهداری می‌شود
  List<String> _history = [];
  
  /// لیست کنونی تاریخچه جستجو را برمی‌گرداند.
  List<String> get history => _history;

  /// بارگذاری تاریخچه از حافظه دائمی (Shared Preferences) هنگام راه‌اندازی.
  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _history = prefs.getStringList(_historyKey) ?? [];
  }

  /// ذخیره یک جستجوی جدید. آیتم‌های تکراری را به بالا منتقل می‌کند.
  Future<void> saveQuery(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    final index = _history.indexOf(trimmedQuery);

    if (index != -1) {
      // اگر از قبل وجود داشت، آن را حذف کن تا دوباره در بالای لیست قرار گیرد
      _history.removeAt(index);
    }
    
    // اضافه کردن به ابتدای لیست
    _history.insert(0, trimmedQuery);

    // محدود کردن اندازه لیست به حداکثر مجاز
    if (_history.length > _maxHistorySize) {
      _history = _history.sublist(0, _maxHistorySize);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _history);
  }

  /// حذف یک آیتم خاص از تاریخچه
  Future<void> removeHistoryItem(String item) async {
    _history.remove(item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _history);
  }

  /// پاک کردن کل تاریخچه
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    _history = []; // پاک کردن لیست در حافظه
  }
}