import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../config/config_url.dart';
import '../models/attendance_record.dart';
import '../models/monthly_wrapped_model.dart';
import '../models/salary_model.dart';
import 'api_client.dart';
import 'location_service.dart';

class AttendanceService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>?> getTodayStatus() async {
    try {
      final response = await _apiClient.get(ConfigUrl.todayStatusUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['data'] is Map<String, dynamic>) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> checkIn({
    required String userId,
    DateTime? checkInTime,
    String? shiftName,
    String? biometricToken,
    String? deviceId,
    String? proofImageBase64,
  }) async {
    try {
      final now = checkInTime ?? DateTime.now();
      final loc = LocationService.lastResult;
      final locRemark = (loc != null && loc.isInside)
          ? 'Radar GPS: Trụ sở (${loc.distanceMeters.round()}m)'
          : 'Chấm công từ ứng dụng nhân viên';

      final body = {
        'userId': userId,
        'checkInTime': now.toIso8601String(),
        'shiftName': shiftName ?? 'Ca Hành Chính (08:00 - 17:00)',
        'authenticationMethod': 'Fingerprint',
        'biometricToken': biometricToken,
        'deviceId': deviceId,
        'proofImageBase64': proofImageBase64,
        'remarks': locRemark,
      };

      final response = await _apiClient.post(ConfigUrl.checkInUrl, body: body);
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 &&
          (data['success'] == true || data['status'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Check-in vào ca thành công!',
          'data': data['data'] != null
              ? AttendanceRecord.fromJson(data['data'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Check-in thất bại.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối khi Check-in: $e'};
    }
  }

  Future<Map<String, dynamic>> checkOut({
    required String userId,
    DateTime? checkOutTime,
    String? biometricToken,
    String? deviceId,
  }) async {
    try {
      final now = checkOutTime ?? DateTime.now();
      final loc = LocationService.lastResult;
      final locRemark = (loc != null && loc.isInside)
          ? 'Tan ca GPS tại Trụ sở (${loc.distanceMeters.round()}m)'
          : 'Tan ca sinh trắc học vân tay chính chủ';

      final body = {
        'userId': userId,
        'checkOutTime': now.toIso8601String(),
        'authenticationMethod': 'Fingerprint',
        'biometricToken': biometricToken,
        'deviceId': deviceId,
        'remarks': locRemark,
      };

      final response = await _apiClient.post(ConfigUrl.checkOutUrl, body: body);
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 &&
          (data['success'] == true || data['status'] == true)) {
        return {
          'success': true,
          'message': data['message'] ?? 'Check-out tan ca thành công!',
          'data': data['data'] != null
              ? AttendanceRecord.fromJson(data['data'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Check-out thất bại.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối khi Check-out: $e'};
    }
  }

  Future<List<AttendanceRecord>> getMyHistory({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      String url = ConfigUrl.myHistoryUrl;
      final queryParams = <String>[];

      if (fromDate != null) {
        queryParams.add('fromDate=${DateFormat('yyyy-MM-dd').format(fromDate)}');
      }
      if (toDate != null) {
        queryParams.add('toDate=${DateFormat('yyyy-MM-dd').format(toDate)}');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await _apiClient.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        List<dynamic> listJson = [];

        if (data is List) {
          listJson = data;
        } else if (data['data'] != null && data['data'] is List) {
          listJson = data['data'];
        }

        return listJson.map((e) => AttendanceRecord.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<SalaryModel?> getMySalary({
    String periodType = 'Month',
    int? year,
    int? month,
    int? weekNumber,
    DateTime? fromDate,
    DateTime? toDate,
    String? periodDescription,
  }) async {
    try {
      String url = ConfigUrl.mySalaryUrl;
      final queryParams = <String>['periodType=$periodType'];

      if (year != null) queryParams.add('year=$year');
      if (month != null) queryParams.add('month=$month');
      if (weekNumber != null) queryParams.add('weekNumber=$weekNumber');
      if (fromDate != null) {
        queryParams.add('fromDate=${DateFormat('yyyy-MM-dd').format(fromDate)}');
      }
      if (toDate != null) {
        queryParams.add('toDate=${DateFormat('yyyy-MM-dd').format(toDate)}');
      }
      if (periodDescription != null) {
        queryParams.add(
            'periodDescription=${Uri.encodeComponent(periodDescription)}');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await _apiClient.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['data'] != null) {
          return SalaryModel.fromJson(data['data']);
        } else if (data['userId'] != null) {
          return SalaryModel.fromJson(data);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> sendMyReportEmail({
    String periodType = 'Month',
    int? year,
    int? month,
    int? weekNumber,
  }) async {
    try {
      final params = <String>['periodType=$periodType'];
      if (year != null) params.add('year=$year');
      if (month != null) params.add('month=$month');
      if (weekNumber != null) params.add('weekNumber=$weekNumber');

      final url = '${ConfigUrl.sendMyReportUrl}?${params.join('&')}';
      final response = await _apiClient.post(url);
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 &&
          (data['success'] == true || data['status'] == true)) {
        return {
          'success': true,
          'message':
              data['message'] ?? 'Báo cáo đã được gửi tới email của bạn!',
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message':
              data['message'] ?? 'Gửi email thất bại. Vui lòng thử lại.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối khi gửi email: $e'};
    }
  }

  /// Lấy bản tổng kết tháng phong cách Spotify (Monthly Work Wrapped)
  Future<MonthlyWrappedModel?> getMonthlyWrapped({int? year, int? month}) async {
    try {
      final y = year ?? DateTime.now().year;
      final m = month ?? DateTime.now().month;
      final url = '${ConfigUrl.monthlyWrappedUrl}?year=$y&month=$m';
      final response = await _apiClient.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['data'] != null) {
          return MonthlyWrappedModel.fromJson(data['data']);
        }
      }
    } catch (e) {
      debugPrint('getMonthlyWrapped error: $e');
    }
    return null;
  }
}
