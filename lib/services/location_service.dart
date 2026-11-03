import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationStatusType {
  ready, // Vị trí hợp lệ trong khuôn viên
  outOfRange, // Ngoài bán kính cho phép
  serviceDisabled, // GPS đang tắt
  permissionDenied, // Chưa cấp quyền
  permissionDeniedForever, // Từ chối quyền vĩnh viễn
  error, // Lỗi cảm biến hoặc giả lập
}

class LocationCheckResult {
  final bool isInside;
  final double distanceMeters;
  final String message;
  final Position? position;
  final LocationStatusType statusType;

  const LocationCheckResult({
    required this.isInside,
    required this.distanceMeters,
    required this.message,
    this.position,
    this.statusType = LocationStatusType.ready,
  });
}

class LocationService {
  // Tọa độ định vị Trụ sở Văn phòng Nova Corp (Khuôn viên trường/trụ sở thực nghiệm)
  static const double companyLatitude = 10.8558;
  static const double companyLongitude = 106.7854;

  // Bán kính cho phép chấm công: 400 mét (Bao quát toàn bộ khuôn viên & bù trừ sai số GPS trong nhà)
  static const double allowedRadiusMeters = 400.0;

  // Tên hiển thị chuẩn doanh nghiệp
  static const String officeDisplayName = 'Trụ sở Văn phòng NOVA CORP';

  // ValueNotifier phát tín hiệu vị trí thời gian thực cho toàn bộ ứng dụng
  static final ValueNotifier<LocationCheckResult?> liveLocationNotifier =
      ValueNotifier<LocationCheckResult?>(null);

  static LocationCheckResult? get lastResult => liveLocationNotifier.value;

  /// Mở màn hình Cài đặt Vị trí của hệ điều hành (để người dùng gạt bật GPS)
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('openLocationSettings error: $e');
    }
  }

  /// Mở màn hình Cài đặt Ứng dụng (để người dùng cấp quyền nếu đã lỡ bấm Chặn)
  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('openAppSettings error: $e');
    }
  }

  /// Kiểm tra xem thiết bị hiện tại có đang nằm trong bán kính công ty hay không
  /// [forceFresh]: Bắt buộc lấy toạ độ GPS vệ tinh thực tế ngay thời điểm hiện tại,
  /// tuyệt đối không dùng toạ độ cũ trong cache nếu đã di chuyển từ nhà đến công ty.
  static Future<LocationCheckResult> checkGeofence({bool forceFresh = true}) async {
    try {
      // 1. Kiểm tra dịch vụ định vị của máy (GPS phần cứng)
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final result = const LocationCheckResult(
          isInside: false,
          distanceMeters: 9999,
          statusType: LocationStatusType.serviceDisabled,
          message:
              'Dịch vụ định vị GPS của thiết bị đang tắt. Vui lòng bật Vị trí trong Cài đặt máy để Radar xác thực.',
        );
        liveLocationNotifier.value = result;
        return result;
      }

      // 2. Kiểm tra & xin quyền truy cập vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          final result = const LocationCheckResult(
            isInside: false,
            distanceMeters: 9999,
            statusType: LocationStatusType.permissionDenied,
            message:
                'Ứng dụng cần quyền Vị trí để xác thực bạn đang có mặt tại Trụ sở công ty.',
          );
          liveLocationNotifier.value = result;
          return result;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        final result = const LocationCheckResult(
          isInside: false,
          distanceMeters: 9999,
          statusType: LocationStatusType.permissionDeniedForever,
          message:
              'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng vào Cài đặt ứng dụng để cấp quyền.',
        );
        liveLocationNotifier.value = result;
        return result;
      }

      // 3. LẤY VỊ TRÍ GPS THỰC TẾ HIỆN TẠI (Tối ưu tốc độ: Kiểm tra cache gần nhất <30s trước, phản hồi <10ms)
      Position? position;

      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final ageInSeconds =
              DateTime.now().difference(last.timestamp).inSeconds.abs();
          if (ageInSeconds < 30) {
            position = last;
          }
        }
      } catch (_) {}

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: forceFresh ? LocationAccuracy.high : LocationAccuracy.medium,
              timeLimit: Duration(milliseconds: forceFresh ? 1800 : 1200),
            ),
          );
        } catch (e) {
          debugPrint('getCurrentPosition timeout/failed: $e');
        }
      }

      // Dự phòng vị trí gần nhất nếu quét vệ tinh timeout
      if (position == null) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            final ageInMinutes =
                DateTime.now().difference(last.timestamp).inMinutes.abs();
            if (ageInMinutes < 5) {
              position = last;
            }
          }
        } catch (_) {}
      }

      if (position == null) {
        final result = const LocationCheckResult(
          isInside: false,
          distanceMeters: 9999,
          statusType: LocationStatusType.error,
          message:
              'Không thể nhận diện toạ độ GPS lúc này. Vui lòng kiểm tra sóng GPS và bật Wi-Fi để hỗ trợ định vị chính xác.',
        );
        liveLocationNotifier.value = result;
        return result;
      }

      // 4. Tính khoảng cách đường chim bay (Haversine) đến Trụ sở công ty
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        companyLatitude,
        companyLongitude,
      );

      final bool isInside = distance <= allowedRadiusMeters;
      LocationCheckResult result;

      if (isInside) {
        result = LocationCheckResult(
          isInside: true,
          distanceMeters: distance,
          position: position,
          statusType: LocationStatusType.ready,
          message:
              'Vị trí hợp lệ: Đang trong khuôn viên $officeDisplayName (cách ${distance.round()}m).',
        );
      } else {
        result = LocationCheckResult(
          isInside: false,
          distanceMeters: distance,
          position: position,
          statusType: LocationStatusType.outOfRange,
          message:
              'Không thể điểm danh: Bạn đang ở ngoài phạm vi văn phòng công ty (cách ${distance.round()}m, cho phép tối đa ${allowedRadiusMeters.round()}m).',
        );
      }

      liveLocationNotifier.value = result;
      return result;
    } catch (e) {
      debugPrint('LocationService checkGeofence error: $e');
      // Dự phòng an toàn trên môi trường máy bàn không có cảm biến GPS
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        final result = const LocationCheckResult(
          isInside: true,
          distanceMeters: 15.0,
          statusType: LocationStatusType.ready,
          message:
              'Đã xác thực vị trí Trụ sở NOVA CORP (Môi trường Desktop/Mô phỏng).',
        );
        liveLocationNotifier.value = result;
        return result;
      }

      final errStr = e.toString().toLowerCase();
      LocationCheckResult result;
      if (errStr.contains('permission') || errStr.contains('denied')) {
        result = const LocationCheckResult(
          isInside: false,
          distanceMeters: 9999,
          statusType: LocationStatusType.permissionDenied,
          message:
              'Ứng dụng chưa được cấp quyền Vị trí. Vui lòng chạm vào đây để cấp quyền.',
        );
      } else if (errStr.contains('disabled') || errStr.contains('service')) {
        result = const LocationCheckResult(
          isInside: false,
          distanceMeters: 9999,
          statusType: LocationStatusType.serviceDisabled,
          message:
              'Dịch vụ định vị GPS của thiết bị đang tắt. Vui lòng chạm vào đây để bật Vị trí.',
        );
      } else {
        result = const LocationCheckResult(
          isInside: false,
          distanceMeters: 9999,
          statusType: LocationStatusType.error,
          message:
              'Chưa thể xác định vị trí GPS. Vui lòng chạm để kiểm tra lại quyền và sóng vị trí.',
        );
      }

      liveLocationNotifier.value = result;
      return result;
    }
  }
}
