import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ConfigUrl {
  static const String defaultNgrok =
      "https://carport-empty-pulp.ngrok-free.dev/api/";
  static const String defaultLocalhost = "http://127.0.0.1:5266/api/";
  static const String defaultLan = "http://192.168.1.12:5266/api/";
  static const String fallbackEmulator = "http://10.0.2.2:5266/api/";

  static String? _customBaseUrl;
  static String? _workingUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _customBaseUrl = prefs.getString('custom_base_url');
    _workingUrl = prefs.getString('last_working_base_url');
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.trim().isNotEmpty) {
      final url = _customBaseUrl!.trim();
      return url.endsWith('/') ? url : '$url/';
    }
    if (_workingUrl != null && _workingUrl!.isNotEmpty) {
      return _workingUrl!;
    }
    final url = dotenv.env['BASE_URL'];
    if (url != null && url.trim().isNotEmpty) {
      final trimmed = url.trim();
      return trimmed.endsWith('/') ? trimmed : '$trimmed/';
    }
    return defaultNgrok;
  }

  static void setWorkingUrl(String url) {
    _workingUrl = url.endsWith('/') ? url : '$url/';
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_working_base_url', _workingUrl!);
    }).catchError((_) {});
  }

  static List<String> get candidateUrls {
    final list = <String>[];
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      final formatted = _customBaseUrl!.endsWith('/') ? _customBaseUrl! : '$_customBaseUrl/';
      if (!list.contains(formatted)) list.add(formatted);
    }

    // ƯU TIÊN SỐ 1: Đường hầm Ngrok cố định vĩnh viễn (Static Domain)
    if (!list.contains(defaultNgrok)) list.add(defaultNgrok);

    final envUrl = dotenv.env['BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      final formatted = envUrl.endsWith('/') ? envUrl : '$envUrl/';
      if (!list.contains(formatted)) list.add(formatted);
    }

    if (_workingUrl != null && _workingUrl!.isNotEmpty) {
      if (!list.contains(_workingUrl!)) list.add(_workingUrl!);
    }

    if (!list.contains(defaultLan)) list.add(defaultLan);
    if (!list.contains(defaultLocalhost)) list.add(defaultLocalhost);
    if (!list.contains(fallbackEmulator)) list.add(fallbackEmulator);
    return list;
  }

  static Future<void> setCustomBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    var trimmed = url.trim();
    if (!trimmed.endsWith('/')) trimmed = '$trimmed/';
    if (!trimmed.toLowerCase().endsWith('/api/')) {
      trimmed = '${trimmed}api/';
    }
    _customBaseUrl = trimmed;
    _workingUrl = null;
    await prefs.setString('custom_base_url', trimmed);
  }

  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_base_url');
    _customBaseUrl = null;
    _workingUrl = null;
  }

  static Future<Map<String, dynamic>> testConnection([String? testUrl]) async {
    final targets = (testUrl != null && testUrl.trim().isNotEmpty)
        ? [
            () {
              var t = testUrl.trim();
              if (!t.endsWith('/')) t = '$t/';
              if (!t.toLowerCase().endsWith('/api/')) t = '${t}api/';
              return t;
            }()
          ]
        : candidateUrls;

    dynamic lastError;
    for (final target in targets) {
      final pingEndpoint = '${target}Authenticate/login';
      try {
        final response = await http
            .post(
              Uri.parse(pingEndpoint),
              headers: {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true',
              },
              body: jsonEncode({'username': '__ping__', 'password': '__ping__'}),
            )
            .timeout(const Duration(milliseconds: 2000));

        if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 200) {
          setWorkingUrl(target);
          return {
            'success': true,
            'url': target,
            'message': 'Kết nối máy chủ thành công!\nĐịa chỉ đang hoạt động: $target',
          };
        }
      } catch (e) {
        lastError = e;
      }
    }

    return {
      'success': false,
      'message':
          'Không thể kết nối máy chủ!\nChi tiết: $lastError\n\nHãy đảm bảo máy tính đang chạy WebAPI_DiemDanh (cổng 5266) và chung mạng Wi-Fi.',
    };
  }

  static String get loginUrl => '${baseUrl}Authenticate/login';
  static String get profileUrl => '${baseUrl}Authenticate/profile';
  static String get changePasswordUrl => '${baseUrl}Authenticate/change-password';
  static String get enrollBiometricUrl => '${baseUrl}Authenticate/enroll-biometric';
  static String get todayStatusUrl => '${baseUrl}Attendance/today';
  static String get checkInUrl => '${baseUrl}Attendance/check-in';
  static String get checkOutUrl => '${baseUrl}Attendance/check-out';
  static String get myHistoryUrl => '${baseUrl}Attendance/my-history';
  static String get mySalaryUrl => '${baseUrl}Salary/my-salary';
  static String get myReportUrl => '${baseUrl}Report/my-report';
  static String get sendMyReportUrl => '${baseUrl}Report/send-my-report';
  static String get monthlyWrappedUrl => '${baseUrl}Attendance/monthly-wrapped';

  /// Trả về URL đầy đủ của ảnh tĩnh được lưu trữ trên Web server (wwwroot)
  static String? formatImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (relativePath.startsWith('http://') || relativePath.startsWith('https://')) {
      return relativePath;
    }
    final host = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    final cleanPath = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    return '$host$cleanPath';
  }
}
