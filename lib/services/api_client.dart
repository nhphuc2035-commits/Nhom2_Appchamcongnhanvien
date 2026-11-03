import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config_url.dart';

class ApiClient {
  final String? _customBaseUrl;

  ApiClient({String? baseUrl}) : _customBaseUrl = baseUrl;

  // Lấy Headers kèm JWT Bearer Token nếu có
  Future<Map<String, String>> _buildHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Thực hiện request có tự động fallback nếu adb reverse tạm thời bị gián đoạn
  Future<http.Response> _executeWithFallback(
    Future<http.Response> Function(String fullUri, Map<String, String> headers) requestFn,
    String endpoint,
  ) async {
    final headers = await _buildHeaders();

    if (endpoint.startsWith('http')) {
      return await requestFn(endpoint, headers).timeout(const Duration(seconds: 10));
    }

    final candidates = _customBaseUrl != null ? [_customBaseUrl] : ConfigUrl.candidateUrls;
    Exception? lastException;

    for (final base in candidates) {
      final formattedBase = base.endsWith('/') ? base : '$base/';
      final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
      final fullUri = '$formattedBase$cleanEndpoint';

      try {
        final response = await requestFn(fullUri, headers)
            .timeout(const Duration(milliseconds: 1800));
        ConfigUrl.setWorkingUrl(base);
        return response;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    throw lastException ?? Exception('Không thể kết nối đến máy chủ.');
  }

  // Kiểm tra chuỗi hoặc ngoại lệ có phải là lỗi mất kết nối mạng hay không
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    final errStr = error.toString().toLowerCase();
    return errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('network is unreachable') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection timed out') ||
        errStr.contains('connection reset') ||
        errStr.contains('kết nối máy chủ') ||
        errStr.contains('kết nối mạng') ||
        errStr.contains('không thể kết nối') ||
        errStr.contains('lỗi kết nối') ||
        errStr.contains('lỗi xử lý phản hồi từ server') ||
        errStr.contains('timeout') ||
        errStr.contains('clientexception');
  }

  // GET Request
  Future<http.Response> get(String endpoint) async {
    return await _executeWithFallback(
      (uri, headers) => http.get(Uri.parse(uri), headers: headers),
      endpoint,
    );
  }

  // POST Request
  Future<http.Response> post(String endpoint, {dynamic body}) async {
    return await _executeWithFallback(
      (uri, headers) => http.post(
        Uri.parse(uri),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      endpoint,
    );
  }

  // PUT Request
  Future<http.Response> put(String endpoint, {dynamic body}) async {
    return await _executeWithFallback(
      (uri, headers) => http.put(
        Uri.parse(uri),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
      endpoint,
    );
  }

  // DELETE Request
  Future<http.Response> delete(String endpoint) async {
    return await _executeWithFallback(
      (uri, headers) => http.delete(Uri.parse(uri), headers: headers),
      endpoint,
    );
  }
}
