import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationStore {
  static const String _storageKey = 'user_app_notifications_v1';
  static final List<AppNotification> _cache = [];
  static bool _isLoaded = false;

  /// ValueNotifier đếm số lượng thông báo CHƯA ĐỌC để cập nhật Badge đỏ tức thì trên giao diện
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Khởi tạo và nạp danh sách thông báo từ bộ nhớ thiết bị
  static Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);

      _cache.clear();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _cache.add(AppNotification.fromJson(item));
          }
        }
      } else {
        // Tạo các thông báo khởi tạo hệ thống chuyên nghiệp cho lần đầu mở app
        _seedInitialNotifications();
        await _saveToDisk();
      }

      _cache.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _updateUnreadCount();
      _isLoaded = true;
    } catch (e) {
      debugPrint('Lỗi nạp NotificationStore: $e');
    }
  }

  static void _seedInitialNotifications() {
    final now = DateTime.now();
    _cache.addAll([
      AppNotification(
        id: 'init_sys_01',
        title: '🎉 CHÀO MỪNG ĐẾN VỚI HỆ THỐNG BIOWORK HRM',
        message:
            'Tài khoản của bạn đã được liên kết với Trụ sở NOVA CORP. Hãy kiểm tra phân công ca và định vị Radar GPS trước khi vào ca làm việc.',
        timestamp: now.subtract(const Duration(hours: 3)),
        type: NotificationType.system,
        isRead: false,
      ),
      AppNotification(
        id: 'init_sys_02',
        title: '🛡️ BẢO MẬT SINH TRẮC HỌC CHÍNH CHỦ',
        message:
            'Hệ thống áp dụng khóa vân tay phần cứng Android Keystore chống gian lận và selfie đối soát khuôn mặt. Mọi dữ liệu đều được mã hóa an toàn.',
        timestamp: now.subtract(const Duration(hours: 1)),
        type: NotificationType.security,
        isRead: false,
      ),
    ]);
  }

  static void _updateUnreadCount() {
    final count = _cache.where((n) => !n.isRead).length;
    unreadCountNotifier.value = count;
  }

  static Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _cache.map((n) => n.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
      _updateUnreadCount();
    } catch (e) {
      debugPrint('Lỗi lưu NotificationStore: $e');
    }
  }

  /// Lấy toàn bộ danh sách thông báo
  static Future<List<AppNotification>> getNotifications() async {
    if (!_isLoaded) await init();
    return List.unmodifiable(_cache);
  }

  /// Thêm thông báo mới vào đầu danh sách và lưu trữ bền vững
  static Future<void> addNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
  }) async {
    if (!_isLoaded) await init();

    final newNotif = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
    );

    _cache.insert(0, newNotif);
    // Giới hạn tối đa 50 thông báo gần nhất để tránh phình bộ nhớ
    if (_cache.length > 50) {
      _cache.removeLast();
    }
    await _saveToDisk();
  }

  /// Đánh dấu 1 thông báo là đã đọc
  static Future<void> markAsRead(String id) async {
    if (!_isLoaded) await init();
    final index = _cache.indexWhere((n) => n.id == id);
    if (index != -1 && !_cache[index].isRead) {
      _cache[index].isRead = true;
      await _saveToDisk();
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  static Future<void> markAllAsRead() async {
    if (!_isLoaded) await init();
    bool changed = false;
    for (final n in _cache) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      await _saveToDisk();
    }
  }

  /// Xóa 1 thông báo khỏi lịch sử
  static Future<void> deleteNotification(String id) async {
    if (!_isLoaded) await init();
    _cache.removeWhere((n) => n.id == id);
    await _saveToDisk();
  }

  /// Xóa sạch toàn bộ lịch sử thông báo
  static Future<void> clearAll() async {
    if (!_isLoaded) await init();
    _cache.clear();
    await _saveToDisk();
  }
}
