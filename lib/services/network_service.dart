import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/config_url.dart';

class NetworkService {
  static bool _lastIsOnline = true;
  static bool get isOnline => _lastIsOnline;

  static final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

  /// Kiểm tra kết nối mạng tức thì (rất nhanh: <50ms nếu mất mạng)
  static Future<bool> checkConnectivity() async {
    // 1. Thử phân giải DNS thông dụng
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 1200));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        _setOnline(true);
        return true;
      }
    } catch (_) {}

    // 2. Thử kết nối trực tiếp IP DNS Google 8.8.8.8 qua cổng 53
    try {
      final socket = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(milliseconds: 1200));
      socket.destroy();
      _setOnline(true);
      return true;
    } catch (_) {}

    // 3. Thử kết nối trực tiếp đến các địa chỉ Backend cấu hình (kể cả mạng LAN / adb reverse)
    for (final url in ConfigUrl.candidateUrls) {
      try {
        final uri = Uri.parse(url);
        if (uri.host.isNotEmpty) {
          final port =
              uri.port > 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
          final socket = await Socket.connect(uri.host, port,
              timeout: const Duration(milliseconds: 1000));
          socket.destroy();
          _setOnline(true);
          return true;
        }
      } catch (_) {}
    }

    _setOnline(false);
    return false;
  }

  static void _setOnline(bool online) {
    if (_lastIsOnline != online) {
      _lastIsOnline = online;
      isOnlineNotifier.value = online;
    }
  }
}
