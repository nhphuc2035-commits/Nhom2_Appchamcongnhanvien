import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config_url.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'biometric_service.dart';

class AuthService {
  static final ApiClient _apiClient = ApiClient();

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final candidates = ConfigUrl.candidateUrls;
    http.Response? response;
    dynamic lastError;

    for (final base in candidates) {
      final loginEndpoint = '${base}Authenticate/login';
      try {
        final res = await http
            .post(
              Uri.parse(loginEndpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': username,
                'password': password,
                'client': 'mobile',
              }),
            )
            .timeout(const Duration(seconds: 4));

        ConfigUrl.setWorkingUrl(base);
        response = res;
        break;
      } catch (e) {
        lastError = e;
      }
    }

    if (response == null) {
      return {
        'success': false,
        'message':
            'Không thể kết nối máy chủ API Backend!\nChi tiết: $lastError\n\nVui lòng đảm bảo WebAPI_DiemDanh đang chạy trên máy tính hoặc bấm nút "Cấu hình máy chủ" bên dưới.',
      };
    }

    try {
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        String? token;
        if (data['token'] != null) {
          token = data['token'];
        } else if (data['data'] != null && data['data']['token'] != null) {
          token = data['data']['token'];
        }

        if (token == null || token.isEmpty) {
          return {
            'success': false,
            'message':
                data['message'] ?? 'Không tìm thấy Token trong phản hồi.',
          };
        }

        final decodedToken = JwtDecoder.decode(token);
        final userData = data['data'] is Map ? data['data'] : null;

        final String role = userData?['role'] ??
            decodedToken['role'] ??
            decodedToken[
                'http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
            'User';

        if (role.toLowerCase() == 'admin') {
          return {
            'success': false,
            'message':
                'Ứng dụng di động chỉ dành cho Nhân viên chấm công. Tài khoản Quản trị viên (Admin) vui lòng sử dụng Web Dashboard trên máy tính.',
          };
        }

        final String userId = userData?['userId'] ??
            decodedToken['nameid'] ??
            decodedToken[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
            decodedToken['sub'] ??
            '';

        final String fullName = userData?['fullName'] ??
            decodedToken['given_name'] ??
            decodedToken[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname'] ??
            username;

        final String department =
            userData?['department'] ?? decodedToken['Department'] ?? '';
        final String position = userData?['position'] ?? 'Nhân viên';
        final String email = userData?['email'] ?? decodedToken['email'] ?? '';
        final bool isBioEnrolled = userData?['isBiometricEnrolled'] ?? false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', username);
        await prefs.setString('last_username', username);
        await prefs.setString('full_name', fullName);
        await prefs.setString('last_full_name', fullName);
        await prefs.setString('user_email', email);
        if (email.isNotEmpty) {
          await prefs.setString('last_email', email);
        } else if (username.contains('@')) {
          await prefs.setString('last_email', username);
        }
        await prefs.setString('user_role', role);
        await prefs.setString('department', department);
        await prefs.setString('position', position);
        await prefs.setBool('is_biometric_enrolled', isBioEnrolled);

        if (isBioEnrolled) {
          await prefs.setString('device_registered_user_id', userId);
          await prefs.setString('device_registered_user_name', fullName);
          await prefs.setString('device_registered_username', username);
        } else {
          // Nếu server báo chưa đăng ký vân tay (hoặc vừa được Admin bấm Reset trên Web):
          // Dọn sạch dữ liệu sinh trắc học cũ trên máy để nhân viên đăng ký lại mới tinh!
          await BiometricService.clearLocalBiometric(userId);
          if (prefs.getString('device_registered_user_id') == userId) {
            await prefs.remove('device_registered_user_id');
            await prefs.remove('device_registered_user_name');
            await prefs.remove('device_registered_username');
          }
        }

        // Lưu mật khẩu cho cả username, email để hỗ trợ đăng nhập 1 chạm vân tay
        if (password.isNotEmpty) {
          await prefs.setString('saved_pwd_${username.toLowerCase()}', password);
          if (email.isNotEmpty) {
            await prefs.setString('saved_pwd_${email.toLowerCase()}', password);
          }
        }

        return {
          'success': true,
          'message': 'Đăng nhập thành công',
          'token': token,
          'userId': userId,
          'fullName': fullName,
          'role': role,
        };
      } else {
        String msg = 'Tên đăng nhập hoặc mật khẩu không đúng.';
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['message'] != null) msg = data['message'];
        } catch (_) {}
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi xử lý phản hồi từ server: $e',
      };
    }
  }

  static UserModel? _cachedCurrentUser;
  static UserModel? get currentUser => _cachedCurrentUser;

  static Future<UserModel?> fetchUserProfile() async {
    try {
      final response = await _apiClient.get('Authenticate/profile');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['data'] != null) {
          final user = UserModel.fromJson(data['data']);
          _cachedCurrentUser = user;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('full_name', user.fullName);
          await prefs.setString('user_email', user.email);
          await prefs.setString('department', user.department ?? '');
          await prefs.setString('position', user.position ?? 'Nhân viên');
          await prefs.setBool('is_biometric_enrolled', user.isBiometricEnrolled);
          if (user.isBiometricEnrolled) {
            await prefs.setString('device_registered_user_id', user.id);
            await prefs.setString('device_registered_user_name', user.fullName);
            await prefs.setString('device_registered_username', user.username);
          } else {
            // Khi Admin vừa bấm Reset vân tay trên Web, server trả về isBiometricEnrolled = false
            // Tự động giải phóng trạng thái khóa thiết bị cũ trên máy
            await BiometricService.clearLocalBiometric(user.id);
            if (prefs.getString('device_registered_user_id') == user.id) {
              await prefs.remove('device_registered_user_id');
              await prefs.remove('device_registered_user_name');
              await prefs.remove('device_registered_username');
            }
          }
          return user;
        }
      }
    } catch (_) {}
    final fallbackUser = await getCurrentUser();
    _cachedCurrentUser = fallbackUser;
    return fallbackUser;
  }

  static Future<Map<String, dynamic>> updateMyProfile({
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? gender,
    String? address,
    String? citizenId,
  }) async {
    try {
      final res = await _apiClient.put(
        'Authenticate/profile',
        body: {
          'phoneNumber': phoneNumber,
          'dateOfBirth': dateOfBirth?.toIso8601String(),
          'gender': gender,
          'address': address,
          'citizenId': citizenId,
        },
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': res.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? 'Đã cập nhật thông tin cá nhân.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _apiClient.post(
        'Authenticate/change-password',
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': res.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? 'Đã xử lý yêu cầu đổi mật khẩu.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final role = prefs.getString('user_role') ?? 'User';
    if (token == null || token.isEmpty || role.toLowerCase() == 'admin') {
      return false;
    }
    try {
      return !JwtDecoder.isExpired(token);
    } catch (_) {
      return false;
    }
  }

  static Future<String> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? '';
  }

  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return null;

    return UserModel(
      id: prefs.getString('user_id') ?? '',
      username: prefs.getString('user_name') ?? '',
      fullName: prefs.getString('full_name') ?? 'Nhân viên',
      email: prefs.getString('user_email') ?? '',
      department: prefs.getString('department') ?? 'Phòng ban',
      position: prefs.getString('position') ?? 'Nhân viên',
      role: prefs.getString('user_role') ?? 'User',
      isBiometricEnrolled: prefs.getBool('is_biometric_enrolled') ?? false,
    );
  }

  static Future<bool> canQuickBiometricLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUser = prefs.getString('last_username');
      if (lastUser == null || lastUser.isEmpty) return false;
      final savedPwd = prefs.getString('saved_pwd_${lastUser.toLowerCase()}');
      return savedPwd != null && savedPwd.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_username');
  }

  static Future<String?> getLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_email') ?? prefs.getString('user_email');
  }

  static Future<String?> getLastFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_full_name');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Xóa chỉ các thông tin phiên đăng nhập hiện tại
    // Bảo toàn 100% cấu hình máy chủ, mật khẩu lưu đăng nhập vân tay và định danh phần cứng máy
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('department');
    await prefs.remove('position');
    await prefs.remove('full_name');
    await prefs.remove('is_biometric_enrolled');
  }
}
