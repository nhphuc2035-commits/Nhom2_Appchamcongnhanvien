import 'dart:convert';
import 'dart:math';
import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class BiometricService {
  static final ApiClient _apiClient = ApiClient();
  static const MethodChannel _securityChannel =
      MethodChannel('com.example.appdiemdanhnhanvien/biometric_security');

  // Trạng thái phần cứng sinh trắc học chi tiết
  static Future<String> getBiometricHardwareState() async {
    try {
      final res = await _securityChannel.invokeMethod<String>('checkBiometricChanged');
      return res ?? 'UNKNOWN';
    } catch (e) {
      debugPrint('getBiometricHardwareState error: $e');
      return 'UNKNOWN';
    }
  }

  // Kiểm tra tức thì không cần chạm ngón tay: Cấu hình vân tay trong Cài đặt máy có bị thay đổi (thêm/xóa) không?
  static Future<bool> isBiometricEnrollmentChanged() async {
    try {
      final res = await _securityChannel.invokeMethod<String>('checkBiometricChanged');
      return res == 'CHANGED' || res == 'NONE_ENROLLED';
    } catch (e) {
      debugPrint('isBiometricEnrollmentChanged error: $e');
      return false;
    }
  }

  // Làm mới / khởi tạo lại khóa giám sát sau khi người dùng xác minh chính chủ thành công
  static Future<void> resetBiometricDetector() async {
    try {
      await _securityChannel.invokeMethod('resetDetectorKey');
    } catch (e) {
      debugPrint('resetBiometricDetector error: $e');
    }
  }

  // Khóa định danh phần cứng máy vật lý (gắn chặt với chiếc điện thoại này)
  static Future<String> getPermanentDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'secure_hardware_device_permanent_id';
    String? devId = prefs.getString(key);

    if (devId == null || devId.isEmpty) {
      // Đọc từ kho lưu trữ unencrypted BiometricStorage phòng khi app xóa cache
      try {
        final storage = await BiometricStorage().getStorage(
          'device_global_id_store',
          options: StorageFileInitOptions(authenticationRequired: false),
        );
        devId = await storage.read();
      } catch (_) {}
    }

    if (devId == null || devId.isEmpty) {
      final random = List<int>.generate(16, (i) => Random.secure().nextInt(256));
      devId = 'DEVICE_HW_${base64UrlEncode(random).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';

      try {
        final storage = await BiometricStorage().getStorage(
          'device_global_id_store',
          options: StorageFileInitOptions(authenticationRequired: false),
        );
        await storage.write(devId);
      } catch (_) {}
    }

    await prefs.setString(key, devId);
    return devId;
  }

  // Kiểm tra thiết bị có hỗ trợ phần cứng sinh trắc học vân tay an toàn không
  static Future<CanAuthenticateResponse> checkBiometricSupport() async {
    try {
      return await BiometricStorage().canAuthenticate();
    } catch (e) {
      debugPrint('BiometricStorage canAuthenticate error: $e');
      return CanAuthenticateResponse.unsupported;
    }
  }

  // Tiện ích kiểm tra nhanh (boolean)
  static Future<bool> canAuthenticate() async {
    final res = await checkBiometricSupport();
    return res == CanAuthenticateResponse.success;
  }

  // Tên file lưu trữ an toàn trong phần cứng thiết bị cho từng nhân viên
  static String _storageName(String userId) =>
      'emp_bio_${userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

  // Lấy đối tượng BiometricStorageFile được bảo vệ bằng Android Keystore phần cứng
  static Future<BiometricStorageFile> _getStorage(String userId, {String? promptReason}) async {
    return await BiometricStorage().getStorage(
      _storageName(userId),
      options: StorageFileInitOptions(
        authenticationRequired: true,
        androidBiometricOnly: true, // Bắt buộc vân tay, ngăn chặn dùng mã PIN/mật mã màn hình
      ),
      promptInfo: PromptInfo(
        androidPromptInfo: AndroidPromptInfo(
          title: 'Xác thực vân tay nhân viên',
          subtitle: promptReason ?? 'Hệ thống điểm danh chính chủ chống gian lận',
          description: 'Vui lòng chạm cảm biến vân tay để xác thực danh tính',
          negativeButton: 'Hủy bỏ',
        ),
      ),
    );
  }

  // Kiểm tra xem nhân viên này đã đăng ký vân tay chống gian lận chưa
  static Future<bool> isEnrolled(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverEnrolled = prefs.getBool('is_biometric_enrolled') ?? false;
      final localEnrolled = prefs.getBool('bio_enrolled_${userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}') ?? false;
      return serverEnrolled || localEnrolled;
    } catch (_) {
      return false;
    }
  }

  // Quét vân tay phần cứng và lấy Khóa Sinh Trắc Học qua BiometricStorage
  static Future<Map<String, dynamic>> authenticateAndGetToken({
    required String userId,
    String reason = 'Quét vân tay để xác thực danh tính điểm danh',
    bool forceReEnroll = false,
  }) async {
    try {
      // 1. Kiểm tra phần cứng sinh trắc học của máy
      final support = await checkBiometricSupport();
      if (support != CanAuthenticateResponse.success) {
        String msg;
        switch (support) {
          case CanAuthenticateResponse.errorNoHardware:
            msg = 'Thiết bị không có cảm biến sinh trắc học vân tay.';
            break;
          case CanAuthenticateResponse.errorNoBiometricEnrolled:
            msg = 'Điện thoại chưa cài đặt vân tay. Vui lòng vào Cài đặt máy để đăng ký vân tay.';
            break;
          case CanAuthenticateResponse.errorHwUnavailable:
            msg = 'Cảm biến vân tay hiện tại không khả dụng. Vui lòng thử lại sau.';
            break;
          case CanAuthenticateResponse.errorPasscodeNotSet:
            msg = 'Điện thoại chưa thiết lập khóa bảo mật màn hình.';
            break;
          default:
            msg = 'Thiết bị không hỗ trợ lưu trữ sinh trắc học an toàn ($support).';
        }
        return {'success': false, 'message': msg};
      }

      final deviceId = await getPermanentDeviceId();
      final storage = await _getStorage(userId, promptReason: reason);

      final prefs = await SharedPreferences.getInstance();
      final userKey = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final wasEnrolled = prefs.getBool('bio_enrolled_$userKey') ??
          prefs.getBool('is_biometric_enrolled') ??
          false;

      // 2. Kích hoạt xác thực vân tay phần cứng để đọc khóa bảo mật
      String? biometricToken;
      if (!forceReEnroll && wasEnrolled) {
        try {
          biometricToken = await storage.read();
        } on AuthException catch (e) {
          if (e.code == AuthExceptionCode.userCanceled || e.code == AuthExceptionCode.canceled) {
            return {'success': false, 'message': 'Bạn đã hủy thao tác quét vân tay.'};
          }
          if (e.code == AuthExceptionCode.timeout) {
            return {'success': false, 'message': 'Hết thời gian quét vân tay. Vui lòng thử lại.'};
          }
          return {'success': false, 'message': e.message};
        } catch (_) {}
      }

      // 3. Nếu chưa có khóa, hoặc khóa cũ bị Android hủy/đổi ngón tay -> Tự động sinh khóa mới và đồng bộ
      if (biometricToken == null || biometricToken.isEmpty || forceReEnroll) {
        final randomBytes = List<int>.generate(32, (i) => Random.secure().nextInt(256));
        biometricToken = 'BIO_HARDWARE_${base64UrlEncode(randomBytes)}';

        try {
          try { await storage.delete(); } catch (_) {}
          await storage.write(biometricToken);
          await resetBiometricDetector();
        } on AuthException catch (e) {
          if (e.code == AuthExceptionCode.userCanceled || e.code == AuthExceptionCode.canceled) {
            return {'success': false, 'message': 'Bạn đã hủy thao tác quét vân tay.'};
          }
          return {'success': false, 'message': 'Không thể ghi khóa bảo mật: ${e.message}'};
        }

        // Tự động đồng bộ khóa vân tay mới lên Server
        try {
          await enrollWithServer(
            userId: userId,
            biometricToken: biometricToken,
            deviceId: deviceId,
          );
        } catch (_) {}
      }

      // Đánh dấu đã kích hoạt và lưu vết mã băm khóa
      await prefs.setBool('bio_enrolled_$userKey', true);
      await prefs.setString('bio_token_hash_$userKey', biometricToken);

      return {
        'success': true,
        'message': 'Xác thực vân tay phần cứng BiometricStorage thành công!',
        'biometricToken': biometricToken,
        'deviceId': deviceId,
      };
    } catch (e) {
      debugPrint('BiometricStorage Error/Recovery: $e');

      // Tự động phục hồi & tạo khóa mới khi người dùng chạm ngón tay mới
      try {
        final storage = await _getStorage(userId, promptReason: reason);
        try { await storage.delete(); } catch (_) {}
        final randomBytes = List<int>.generate(32, (i) => Random.secure().nextInt(256));
        final biometricToken = 'BIO_HARDWARE_${base64UrlEncode(randomBytes)}';
        await storage.write(biometricToken);
        await resetBiometricDetector();
        final prefs = await SharedPreferences.getInstance();
        final userKey = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        await prefs.setBool('bio_enrolled_$userKey', true);
        await prefs.setString('bio_token_hash_$userKey', biometricToken);

        await enrollWithServer(
          userId: userId,
          biometricToken: biometricToken,
          deviceId: await getPermanentDeviceId(),
        );

        return {
          'success': true,
          'message': 'Xác thực vân tay phần cứng thành công!',
          'biometricToken': biometricToken,
          'deviceId': await getPermanentDeviceId(),
        };
      } catch (err) {
        return {
          'success': false,
          'message': 'Không thể kích hoạt sinh trắc học: $err',
        };
      }
    }
  }

  // Kiểm tra trước xem thiết bị vật lý này đã được đăng ký chính chủ cho nhân viên khác chưa (Pre-check)
  static Future<Map<String, dynamic>> checkDeviceOwnership({
    required String currentUserId,
    String? currentUserName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Nếu người yêu cầu chính là chủ nhân đã lưu trên máy (trùng ID hoặc trùng Họ tên) -> Cho phép ngay!
      final savedOwnerId = prefs.getString('device_registered_user_id');
      final savedOwnerName = prefs.getString('device_registered_user_name');

      if (savedOwnerId == currentUserId ||
          (currentUserName != null &&
              currentUserName.trim().isNotEmpty &&
              savedOwnerName != null &&
              savedOwnerName.trim().toLowerCase() == currentUserName.trim().toLowerCase())) {
        return {'isBlocked': false};
      }

      // 2. Nếu máy lưu chủ nhân là một NGƯỜI KHÁC:
      // Chỉ block nếu người khác đó THỰC SỰ đang có vân tay hợp lệ trên máy này
      if (savedOwnerId != null &&
          savedOwnerId.isNotEmpty &&
          savedOwnerId != currentUserId) {
        final otherKey = savedOwnerId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final otherHasBio = (prefs.getBool('bio_enrolled_$otherKey') ?? false) ||
            (prefs.getString('bio_token_hash_$otherKey')?.isNotEmpty ?? false);

        if (otherHasBio) {
          final name = (savedOwnerName != null && savedOwnerName.isNotEmpty)
              ? savedOwnerName
              : 'Nhân viên khác';
          return {
            'isBlocked': true,
            'ownerName': name,
            'message':
                'CẢNH BÁO BẢO MẬT: Chiếc điện thoại này đã được đăng ký chính chủ cho nhân viên "$name".\n\nMỗi điện thoại chỉ được liên kết cho 1 nhân viên duy nhất để chống điểm danh hộ!',
          };
        }
      }

      final currentKey = currentUserId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      // 3. Quét qua các key bio_enrolled_ của người khác
      final allBioKeys = prefs.getKeys().where((k) => k.startsWith('bio_enrolled_')).toList();
      for (final key in allBioKeys) {
        if (prefs.getBool(key) == true) {
          final enrolledKey = key.replaceFirst('bio_enrolled_', '');
          if (enrolledKey != currentKey) {
            final name = (savedOwnerName != null && savedOwnerName.isNotEmpty)
                ? savedOwnerName
                : 'Nhân viên khác';
            return {
              'isBlocked': true,
              'ownerName': name,
              'message':
                  'CẢNH BÁO BẢO MẬT: Chiếc điện thoại này đã được đăng ký chính chủ cho nhân viên "$name".\n\nMỗi điện thoại chỉ được liên kết cho 1 nhân viên duy nhất để chống điểm danh hộ!',
            };
          }
        }
      }

      return {'isBlocked': false};
    } catch (e) {
      debugPrint('checkDeviceOwnership error: $e');
      return {'isBlocked': false};
    }
  }

  // Đăng ký và liên kết khóa sinh trắc học vào hồ sơ nhân viên trên Backend
  static Future<Map<String, dynamic>> enrollWithServer({
    required String userId,
    required String biometricToken,
    required String deviceId,
  }) async {
    try {
      final response = await _apiClient.post(
        'Authenticate/enroll-biometric',
        body: {
          'biometricToken': biometricToken,
          'deviceId': deviceId,
        },
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final isSuccess = response.statusCode == 200 && (data['success'] == true || data['status'] == true);

      if (isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        final userKey = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        await prefs.setBool('bio_enrolled_$userKey', true);
        await prefs.setString('bio_token_hash_$userKey', biometricToken);
        await prefs.setBool('is_biometric_enrolled', true);
        await prefs.setString('device_registered_user_id', userId);
        final currentFullName = prefs.getString('full_name') ?? prefs.getString('last_full_name') ?? '';
        if (currentFullName.isNotEmpty) {
          await prefs.setString('device_registered_user_name', currentFullName);
        }
        await resetBiometricDetector();
      }

      return {
        'success': isSuccess,
        'message': data['message'] ?? 'Hoàn tất liên kết sinh trắc học với máy chủ.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi liên kết máy chủ: $e'};
    }
  }

  // Xóa vân tay cục bộ khi reset hoặc đổi máy
  static Future<void> clearLocalBiometric(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      await prefs.remove('bio_enrolled_$userKey');
      await prefs.remove('bio_token_hash_$userKey');
      await prefs.remove('is_biometric_enrolled');
      await prefs.remove('device_registered_user_id');
      await prefs.remove('device_registered_user_name');
      await prefs.remove('device_registered_username');

      try {
        final storage = await _getStorage(userId);
        await storage.delete();
      } catch (_) {}

      await resetBiometricDetector();
    } catch (e) {
      debugPrint('Clear biometric error: $e');
    }
  }
}
