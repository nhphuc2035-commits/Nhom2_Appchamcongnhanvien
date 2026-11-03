import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';
import 'notification_store.dart';

/// Dịch vụ Thông Báo Toàn Cục (System Push & Local Notifications)
/// Phát chuông reo, rung và hiển thị banner ngoài màn hình khóa điện thoại
/// khi phát hiện nhân viên đến văn phòng quên Vào ca hoặc ra về quên Tan ca.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Tránh spam chuông liên tục (chỉ reo nhắc nhở cách nhau tối thiểu 20 phút hoặc 1 lần/ngày)
  static DateTime? _lastCheckInAlertTime;
  static DateTime? _lastCheckOutAlertTime;

  static const String channelId = 'nova_attendance_reminders';
  static const String channelName = 'Nhắc Nhở Chấm Công Nova Corp';
  static const String channelDesc =
      'Phát chuông, rung và gửi thông báo nhắc nhở vào ca, tan ca và chống quên điểm danh';

  /// Khởi tạo hệ thống thông báo đa nền tảng
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      await NotificationStore.init();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Đã bấm vào thông báo: ${response.payload}');
        },
      );

      // Tạo Kênh thông báo Ưu tiên Cao nhất (Max Importance) trên Android
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

        // Xin quyền gửi thông báo (Đặc biệt Android 13+ API 33)
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('NotificationService đã sẵn sàng.');
    } catch (e) {
      debugPrint('Lỗi khởi tạo NotificationService: $e');
    }
  }

  /// Phát chuông & Banner: Nhắc Vào Ca khi đến văn phòng
  static Future<void> notifyCheckInNeeded({required String shiftName}) async {
    final now = DateTime.now();
    if (_lastCheckInAlertTime != null &&
        now.difference(_lastCheckInAlertTime!).inMinutes < 20) {
      return; // Đã nhắc trong vòng 20 phút qua, không reo spam
    }
    _lastCheckInAlertTime = now;

    const title = '⏰ BẠN ĐÃ ĐẾN VĂN PHÒNG NOVA CORP!';
    final body =
        'Đừng quên bấm Vào Ca [$shiftName] trên app ngay để hệ thống bắt đầu tính giờ làm nhé.';

    await NotificationStore.addNotification(
      title: title,
      message: body,
      type: NotificationType.checkIn,
    );

    await _showNotification(
      id: 1001,
      title: title,
      body: body,
      payload: 'check_in_reminder',
    );
  }

  /// Phát chuông & Banner: CẢNH BÁO Quên Tan Ca khi rời văn phòng
  static Future<void> notifyCheckOutNeeded({required String shiftName}) async {
    final now = DateTime.now();
    if (_lastCheckOutAlertTime != null &&
        now.difference(_lastCheckOutAlertTime!).inMinutes < 20) {
      return; // Đã nhắc trong vòng 20 phút qua, không reo spam
    }
    _lastCheckOutAlertTime = now;

    const title = '⚠️ CẢNH BÁO QUÊN BẤM TAN CA!';
    final body =
        'Hệ thống phát hiện bạn đã rời khỏi văn phòng nhưng chưa bấm Tan Ca [$shiftName]. Hãy bấm Check-out ngay để tránh bị khóa ca!';

    await NotificationStore.addNotification(
      title: title,
      message: body,
      type: NotificationType.checkOut,
    );

    await _showNotification(
      id: 1002,
      title: title,
      body: body,
      payload: 'check_out_warning',
    );
  }

  /// Lưu lịch sử xác nhận điểm danh thành công
  static Future<void> notifyAttendanceSuccess({
    required bool isCheckIn,
    required String shiftName,
    required String timeStr,
  }) async {
    final title = isCheckIn
        ? '✅ ĐIỂM DANH VÀO CA THÀNH CÔNG'
        : '🏁 ĐIỂM DANH TAN CA THÀNH CÔNG';
    final body = isCheckIn
        ? 'Bạn đã hoàn tất Check-in [$shiftName] lúc $timeStr. Chúc bạn một ngày làm việc hiệu quả!'
        : 'Bạn đã hoàn tất Check-out [$shiftName] lúc $timeStr. Dữ liệu giờ làm đã được đồng bộ với máy chủ.';

    await NotificationStore.addNotification(
      title: title,
      message: body,
      type: isCheckIn ? NotificationType.checkIn : NotificationType.checkOut,
    );

    // Phát tức thời ra thanh thông báo điện thoại (kèm chuông reo & rung không trễ)
    await _showNotification(
      id: isCheckIn ? 1003 : 1004,
      title: title,
      body: body,
      payload: isCheckIn ? 'check_in_success' : 'check_out_success',
    );
  }

  /// Phát thông báo chung có chuông & rung
  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await init();

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.reminder,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Lỗi phát chuông thông báo: $e');
    }
  }
}
