import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../models/user_model.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/biometric_service.dart';
import '../services/location_service.dart';
import '../services/network_service.dart';
import '../services/notification_service.dart';
import '../services/notification_store.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_attendance_button.dart';
import '../widgets/clock_widget.dart';
import '../widgets/modern_animated_dialogs.dart';
import '../widgets/notification_center_sheet.dart';
import '../widgets/staggered_animations.dart';
import 'history_screen.dart';
import 'monthly_wrapped_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onNavigateToProfile;
  final ScrollController? scrollController;

  const HomeScreen({
    super.key,
    this.onNavigateToHistory,
    this.onNavigateToProfile,
    this.scrollController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  ScrollController? _internalScrollController;
  ScrollController get _activeScrollController =>
      widget.scrollController ??
      (_internalScrollController ??= ScrollController());

  final AttendanceService _attendanceService = AttendanceService();
  UserModel? _currentUser;
  AttendanceRecord? _todayRecord;
  List<AttendanceRecord> _monthRecords = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _selectedShift = 'Ca Hành Chính (08:00 - 17:00)';
  LocationCheckResult? _locationStatus;
  String? _smartReminder;
  Timer? _locationTimer;
  Timer? _networkTimer;
  bool _isOffline = false;
  final ScrollController _shiftScrollController = ScrollController();

  static const List<Map<String, dynamic>> _shiftCatalog = [
    {
      'name': 'Ca Hành Chính (08:00 - 17:00)',
      'short': 'Hành Chính (08:00-17:00)',
      'hoursText': '08:00 – 17:00 (chuẩn 8 tiếng)',
      'gateText': '07:15 – 10:30',
      'graceText': 'Trước 08:00',
      'gate':
          'Cổng mở: 07:15 - 10:30 • Đúng giờ: trước 08:00 • Tan ca: 17:00',
      'startMinutes': 8 * 60,
      'endMinutes': 17 * 60,
      'earliestMinutes': 7 * 60 + 15,
      'latestMinutes': 10 * 60 + 30,
    },
    {
      'name': 'Ca Sáng (06:00 - 12:00)',
      'short': 'Ca Sáng (06:00-12:00)',
      'hoursText': '06:00 – 12:00 (chuẩn 6 tiếng)',
      'gateText': '05:15 – 08:30',
      'graceText': 'Trước 06:00',
      'gate':
          'Cổng mở: 05:15 - 08:30 • Đúng giờ: trước 06:00 • Tan ca: 12:00',
      'startMinutes': 6 * 60,
      'endMinutes': 12 * 60,
      'earliestMinutes': 5 * 60 + 15,
      'latestMinutes': 8 * 60 + 30,
    },
    {
      'name': 'Ca Chiều (14:00 - 22:00)',
      'short': 'Ca Chiều (14:00-22:00)',
      'hoursText': '14:00 – 22:00 (chuẩn 8 tiếng)',
      'gateText': '12:00 – 17:00',
      'graceText': 'Trước 14:00',
      'gate':
          'Cổng mở: 12:00 - 17:00 • Đúng giờ: trước 14:00 • Tan ca: 22:00',
      'startMinutes': 14 * 60,
      'endMinutes': 22 * 60,
      'earliestMinutes': 12 * 60,
      'latestMinutes': 17 * 60,
    },
    {
      'name': 'Ca Tối (18:00 - 22:00)',
      'short': 'Tăng Ca Tối (18:00-22:00)',
      'hoursText': '18:00 – 22:00 (tăng ca tự nguyện, tối đa 4 tiếng)',
      'gateText': '17:30 – 21:00',
      'graceText': 'Tự do trong ca (làm bao nhiêu tính bấy nhiêu)',
      'gate':
          'Cổng mở: 17:30 - 21:00 • Tăng ca tự do • Tan ca: 22:00',
      'startMinutes': 18 * 60,
      'endMinutes': 22 * 60,
      'earliestMinutes': 17 * 60 + 30,
      'latestMinutes': 21 * 60,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startLocationPeriodicTimer();
    _startNetworkMonitor();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _networkTimer?.cancel();
    _shiftScrollController.dispose();
    _internalScrollController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNetworkStatus();
      _refreshLocationSilently();
      _loadData();
    }
  }

  void _startNetworkMonitor() {
    _networkTimer?.cancel();
    _checkNetworkStatus();
    _networkTimer =
        Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _checkNetworkStatus();
    });
  }

  Future<void> _checkNetworkStatus() async {
    if (!mounted) return;
    final online = await NetworkService.checkConnectivity();
    if (!online) {
      if (!_isOffline) {
        _isOffline = true;
        if (mounted) {
          setState(() {});
          ModernAnimatedDialogs.showNoInternetDialog(context: context);
        }
      }
    } else {
      if (_isOffline) {
        _isOffline = false;
        ModernAnimatedDialogs.dismissActiveNoInternetDialog();
        if (mounted) {
          setState(() {});
          _loadData();
        }
      }
    }
  }

  void _startLocationPeriodicTimer() {
    _locationTimer?.cancel();
    // Tự động quét radar GPS định kỳ 20 giây một lần để luôn cập nhật vị trí thời gian thực
    _locationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshLocationSilently();
    });
  }

  Future<void> _refreshLocationSilently() async {
    if (!mounted || _isProcessing) return;
    try {
      final loc = await LocationService.checkGeofence(forceFresh: true);
      if (mounted) {
        setState(() => _locationStatus = loc);
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthService.fetchUserProfile();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final history = await _attendanceService.getMyHistory(fromDate: monthStart);

    final today = DateTime(now.year, now.month, now.day);
    AttendanceRecord? todayRec;
    for (final r in history) {
      final rDate = DateTime(
        r.attendanceDate.year,
        r.attendanceDate.month,
        r.attendanceDate.day,
      );
      if (rDate == today) {
        todayRec = r;
        break;
      }
    }

    // Kiểm tra vị trí Radar GPS bán kính Trụ sở Nova Corp
    LocationCheckResult? locResult;
    try {
      locResult = await LocationService.checkGeofence(forceFresh: true);
    } catch (_) {}

    // Thuật toán Nhắc nhở thông minh chống quên (Reo chuông & Banner màn hình khóa)
    String? reminderMsg;
    final assignedShiftForReminder =
        user?.assignedShift ?? 'Ca Hành Chính (08:00 - 17:00)';

    if (locResult != null && locResult.isInside && todayRec == null) {
      // Đã có mặt tại văn phòng nhưng chưa Check-in: Bật chuông & Banner trên điện thoại
      reminderMsg =
          '💡 Bạn đang có mặt tại Trụ sở Nova Corp! Đừng quên bấm Vào Ca để bắt đầu tính giờ làm.';
      NotificationService.notifyCheckInNeeded(
        shiftName: assignedShiftForReminder,
      );
    } else if (todayRec != null && todayRec.checkOutTime == null) {
      if (locResult != null && !locResult.isInside) {
        // Đã rời khuôn viên công ty nhưng chưa Check-out: Bật chuông cảnh báo
        reminderMsg =
            '⚠️ Cảnh báo quên Tan Ca: Hệ thống phát hiện bạn đã rời khỏi văn phòng nhưng chưa bấm Tan Ca!';
        NotificationService.notifyCheckOutNeeded(
          shiftName: todayRec.shiftName,
        );
      }
    }

    if (mounted) {
      final assigned = user?.assignedShift ?? 'Ca Hành Chính (08:00 - 17:00)';
      final isAssignedAfternoon = assigned.contains('Chiều');
      String defaultShift = assigned == 'Xoay ca linh hoạt'
          ? 'Ca Hành Chính (08:00 - 17:00)'
          : assigned;

      final nowMins = now.hour * 60 + now.minute;
      final bool isEveningOtWindow = !isAssignedAfternoon &&
          nowMins >= 17 * 60 + 30 &&
          nowMins <= 21 * 60;

      if (todayRec != null) {
        if (todayRec.checkOutTime != null && isEveningOtWindow) {
          // Đã hoàn tất ca chính trong ngày, hiện tại đang trong khung giờ mở cổng Ca Tối (chỉ áp dụng ca sáng/hành chính)
          defaultShift = 'Ca Tối (18:00 - 22:00)';
        } else {
          defaultShift = todayRec.shiftName;
        }
      } else {
        // Chưa vào ca: Nếu ca phân công đã quá giờ đóng cổng check-in mà đang trong giờ Ca Tối
        final assignedMeta = _shiftCatalog.firstWhere(
          (s) => s['name'] == defaultShift,
          orElse: () => _shiftCatalog.first,
        );
        final int assignedLatest = assignedMeta['latestMinutes'] as int;
        if (!isAssignedAfternoon && nowMins > assignedLatest && isEveningOtWindow) {
          defaultShift = 'Ca Tối (18:00 - 22:00)';
        }
      }

      setState(() {
        _currentUser = user;
        _todayRecord = todayRec;
        _monthRecords = history;
        _selectedShift = defaultShift;
        _locationStatus = locResult;
        _smartReminder = reminderMsg;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_shiftScrollController.hasClients) return;
        final idx = _shiftCatalog.indexWhere((s) => s['name'] == defaultShift);
        if (idx >= 2) {
          _shiftScrollController.animateTo(
            _shiftScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _handleEnrollBiometricNow() async {
    if (_currentUser == null) return;

    if (_isOffline || !NetworkService.isOnline) {
      ModernAnimatedDialogs.showNoInternetDialog(context: context);
      return;
    }

    // Luôn đồng bộ hồ sơ mới nhất từ server trước khi kiểm tra (phát hiện nếu vừa được Admin reset)
    final freshUser = await AuthService.fetchUserProfile();
    if (freshUser != null) {
      _currentUser = freshUser;
    }

    // 0. PRE-CHECK: Kiểm tra xem điện thoại này đã được liên kết với nhân viên nào khác chưa
    final preCheck = await BiometricService.checkDeviceOwnership(
      currentUserId: _currentUser!.id,
      currentUserName: _currentUser!.fullName,
    );
    if (preCheck['isBlocked'] == true) {
      if (mounted) {
        ModernAnimatedDialogs.showSecurityWarning(
          context: context,
          title: 'Thiết Bị Đã Được Đăng Ký',
          message: preCheck['message'] ??
              'Điện thoại này đã được đăng ký chính chủ cho nhân viên khác. Mỗi máy chỉ thuộc 1 nhân viên!',
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    final bioResult = await BiometricService.authenticateAndGetToken(
      userId: _currentUser!.id,
      reason: 'Quét vân tay cài đặt trên máy để đăng ký định danh nhân viên',
      forceReEnroll: true,
    );

    if (bioResult['success'] != true) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ModernAnimatedDialogs.showSecurityWarning(
          context: context,
          title: 'Chưa Thể Đăng Ký Vân Tay',
          message:
              bioResult['message'] ?? 'Xác thực vân tay không thành công.',
        );
      }
      return;
    }

    final srvResult = await BiometricService.enrollWithServer(
      userId: _currentUser!.id,
      biometricToken: bioResult['biometricToken'],
      deviceId: bioResult['deviceId'],
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (srvResult['success'] == true) {
      await ModernAnimatedDialogs.showSuccessBiometric(
        context: context,
        title: 'Đăng Ký Vân Tay Thành Công!',
        employeeName: _currentUser!.fullName,
        timeString: DateFormat('HH:mm:ss - dd/MM/yyyy').format(DateTime.now()),
        statusText: 'Đã Liên Kết Thiết Bị Chính Chủ',
      );
      _loadData();
    } else {
      final msg = srvResult['message'] ?? 'Không thể liên kết thiết bị.';
      if (ApiClient.isNetworkError(msg)) {
        ModernAnimatedDialogs.showNoInternetDialog(context: context);
      } else {
        ModernAnimatedDialogs.showSecurityWarning(
          context: context,
          title: 'Liên Kết Không Thành Công',
          message: msg,
        );
      }
    }
  }

  String? _validateShiftGateBeforeScan(String shiftName) {
    final assigned =
        _currentUser?.assignedShift ?? 'Ca Hành Chính (08:00 - 17:00)';
    final isFlexible = assigned.toLowerCase().contains('xoay ca') ||
        assigned.toLowerCase().contains('linh hoạt');
    final isAssignedAfternoon = assigned.contains('Chiều');

    if (isAssignedAfternoon && shiftName == 'Ca Tối (18:00 - 22:00)') {
      return 'Bạn được phân công Ca Chiều (14:00 - 22:00). Giờ làm việc của bạn đã bao gồm thời gian buổi tối đến 22:00 nên không áp dụng Ca Tối.';
    }

    if (!isFlexible &&
        shiftName != assigned &&
        shiftName != 'Ca Tối (18:00 - 22:00)') {
      return 'Bạn được Admin phân công cố định [$assigned], không được phép chấm công vào [$shiftName]. Vui lòng chọn đúng ca được phân công.';
    }

    final meta = _shiftCatalog.firstWhere(
      (s) => s['name'] == shiftName,
      orElse: () => _shiftCatalog.first,
    );
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final int earliest = meta['earliestMinutes'] as int;
    final int latest = meta['latestMinutes'] as int;
    final String gateText = meta['gateText'] as String;
    final String nowStr = DateFormat('HH:mm').format(now);

    if (nowMins < earliest) {
      return 'Chưa đến giờ mở cổng chấm công cho [$shiftName]. Khung giờ mở cổng vào ca: $gateText (giờ hiện tại: $nowStr).';
    }
    if (nowMins > latest) {
      return 'Đã qua khung giờ mở cổng cho phép vào [$shiftName] (cổng mở $gateText, giờ hiện tại: $nowStr). Nếu bạn làm tăng cường buổi tối, vui lòng chọn "Tăng Ca Tối (18:00-22:00)" hoặc báo Quản lý chấm công bù.';
    }
    return null;
  }

  Future<void> _handleCheckIn() async {
    if (_currentUser == null) return;

    if (_isOffline || !NetworkService.isOnline) {
      ModernAnimatedDialogs.showNoInternetDialog(context: context);
      return;
    }

    // 1. Kiểm tra Radar Bán kính GPS Trụ sở Văn phòng Nova Corp (Phản hồi tức thì)
    final loc = _locationStatus ?? await LocationService.checkGeofence();
    if (!mounted) return;
    setState(() => _locationStatus = loc);
    if (!loc.isInside) {
      String title = 'Ngoài Phạm Vi Văn Phòng';
      String? actionLabel;
      VoidCallback? onAction;

      if (loc.statusType == LocationStatusType.serviceDisabled) {
        title = 'Yêu Cầu Bật Định Vị GPS';
        actionLabel = 'Mở Cài Đặt Vị Trí';
        onAction = () => LocationService.openLocationSettings();
      } else if (loc.statusType == LocationStatusType.permissionDenied ||
          loc.statusType == LocationStatusType.permissionDeniedForever) {
        title = 'Yêu Cầu Cấp Quyền Vị Trí';
        actionLabel = 'Mở Cài Đặt Ứng Dụng';
        onAction = () => LocationService.openAppSettings();
      }

      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: title,
        message: loc.message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
      return;
    }

    final shiftError = _validateShiftGateBeforeScan(_selectedShift);
    if (shiftError != null) {
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Ngoài Khung Giờ Quy Định Của Ca',
        message: shiftError,
      );
      return;
    }

    final freshUser = await AuthService.fetchUserProfile();
    if (freshUser != null) {
      _currentUser = freshUser;
    }

    if (!_currentUser!.isBiometricEnrolled) {
      if (!mounted) return;
      final confirmEnroll = await ModernAnimatedDialogs.showConfirmAction(
        context: context,
        title: 'Yêu Cầu Đăng Ký Vân Tay',
        message:
            'Tài khoản của bạn chưa đăng ký khóa vân tay định danh trên thiết bị này (hoặc vừa được Admin mở lại quyền đăng ký). Bạn có muốn quét vân tay để đăng ký và điểm danh ngay bây giờ không?',
        confirmText: 'Đăng Ký Ngay',
        confirmColor: AppTheme.primary,
        icon: Icons.fingerprint_rounded,
      );
      if (confirmEnroll) {
        await _handleEnrollBiometricNow();
      }
      return;
    }

    // 2. Chụp ảnh Selfie đối soát khoảnh khắc lúc vào ca
    String? proofBase64;
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 70,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        proofBase64 = base64Encode(bytes);
      }
    } catch (e) {
      debugPrint('Selfie capture fallback: $e');
    }

    // 3. Quét vân tay sinh trắc học chính chủ
    final bioResult = await BiometricService.authenticateAndGetToken(
      userId: _currentUser!.id,
      reason: 'Quét vân tay chính chủ để Điểm Danh Vào Ca',
    );

    if (bioResult['success'] != true) {
      if (mounted) {
        final msg = bioResult['message'] ?? 'Xác thực vân tay không thành công';
        if (msg.contains('hủy')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppTheme.amber),
          );
        } else {
          ModernAnimatedDialogs.showSecurityWarning(
            context: context,
            title: bioResult['isBiometricChanged'] == true
                ? 'Cấu Hình Vân Tay Đã Đổi'
                : 'Cảnh Báo Bảo Mật',
            message: msg,
          );
        }
      }
      return;
    }

    setState(() => _isProcessing = true);

    final result = await _attendanceService.checkIn(
      userId: _currentUser!.id,
      checkInTime: DateTime.now(),
      shiftName: _selectedShift,
      biometricToken: bioResult['biometricToken'],
      deviceId: bioResult['deviceId'],
      proofImageBase64: proofBase64,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result['success'] == true) {
      final timeStr =
          DateFormat('HH:mm:ss - dd/MM/yyyy').format(DateTime.now());
      NotificationService.notifyAttendanceSuccess(
        isCheckIn: true,
        shiftName: _selectedShift,
        timeStr: timeStr,
      );
      await ModernAnimatedDialogs.showSuccessAttendance(
        context: context,
        title: 'Điểm Danh Vào Ca Thành Công!',
        employeeName: _currentUser!.fullName,
        timeString: timeStr,
        isCheckIn: true,
      );
      _loadData();
    } else {
      final msg = result['message'] ?? 'Check-in thất bại.';
      if (ApiClient.isNetworkError(msg)) {
        ModernAnimatedDialogs.showNoInternetDialog(context: context);
      } else {
        ModernAnimatedDialogs.showSecurityWarning(
          context: context,
          title: 'Điểm Danh Không Hợp Lệ',
          message: msg,
        );
      }
    }
  }

  Future<void> _handleCheckOut() async {
    if (_currentUser == null) return;

    if (_isOffline || !NetworkService.isOnline) {
      ModernAnimatedDialogs.showNoInternetDialog(context: context);
      return;
    }

    // 1. Kiểm tra Radar Bán kính GPS Trụ sở Văn phòng Nova Corp (Phản hồi tức thì)
    final loc = _locationStatus ?? await LocationService.checkGeofence();
    if (!mounted) return;
    setState(() => _locationStatus = loc);
    if (!loc.isInside) {
      String title = 'Ngoài Phạm Vi Văn Phòng';
      String? actionLabel;
      VoidCallback? onAction;

      if (loc.statusType == LocationStatusType.serviceDisabled) {
        title = 'Yêu Cầu Bật Định Vị GPS';
        actionLabel = 'Mở Cài Đặt Vị Trí';
        onAction = () => LocationService.openLocationSettings();
      } else if (loc.statusType == LocationStatusType.permissionDenied ||
          loc.statusType == LocationStatusType.permissionDeniedForever) {
        title = 'Yêu Cầu Cấp Quyền Vị Trí';
        actionLabel = 'Mở Cài Đặt Ứng Dụng';
        onAction = () => LocationService.openAppSettings();
      }

      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: title,
        message: loc.message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
      return;
    }

    if (_todayRecord?.checkInTime != null) {
      final elapsedSeconds =
          DateTime.now().difference(_todayRecord!.checkInTime!).inSeconds;
      if (elapsedSeconds < 60) {
        if (!mounted) return;
        final inStr = DateFormat('HH:mm:ss').format(_todayRecord!.checkInTime!);
        ModernAnimatedDialogs.showSecurityWarning(
          context: context,
          title: 'Chưa Đủ Thời Gian Tối Thiểu',
          message:
              'Bạn vừa vào ca lúc $inStr. Quy định cần tối thiểu 1 phút sau khi vào ca mới được bấm Tan ca để tránh thao tác nhầm.',
        );
        return;
      }
    }

    final shiftName = _todayRecord?.shiftName ?? _selectedShift;
    final nowTime = DateTime.now();
    final nowMins = nowTime.hour * 60 + nowTime.minute;
    int maxOutMins = 18 * 60; // Ca Hành chính khóa cổng tan ca lúc 18:00
    String maxStr = '18:00';
    if (shiftName.contains('Sáng')) {
      maxOutMins = 12 * 60 + 15;
      maxStr = '12:15';
    } else if (shiftName.contains('Chiều') || shiftName.contains('Tối')) {
      maxOutMins = 22 * 60 + 30;
      maxStr = '22:30';
    }

    if (nowMins > maxOutMins) {
      if (!mounted) return;
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Ngoài Khung Giờ Tan Ca Cho Phép',
        message:
            'Đã qua thời gian cho phép tan ca của [$shiftName] (cổng tan ca đóng lúc $maxStr). Ca làm việc đã bị khóa tự động để tránh trục lợi giờ công. Vui lòng báo Quản lý xác nhận giờ làm thực tế.',
      );
      return;
    }

    if (!_currentUser!.isBiometricEnrolled) {
      if (!mounted) return;
      final confirmEnroll = await ModernAnimatedDialogs.showConfirmAction(
        context: context,
        title: 'Yêu Cầu Đăng Ký Vân Tay',
        message:
            'Tài khoản của bạn chưa đăng ký khóa vân tay định danh trên thiết bị này. Bạn có muốn quét vân tay để đăng ký và điểm danh tan ca ngay bây giờ không?',
        confirmText: 'Đăng Ký Ngay',
        confirmColor: AppTheme.primary,
        icon: Icons.fingerprint_rounded,
      );
      if (confirmEnroll) {
        await _handleEnrollBiometricNow();
      }
      return;
    }

    final bioResult = await BiometricService.authenticateAndGetToken(
      userId: _currentUser!.id,
      reason: 'Quét vân tay chính chủ để Điểm Danh Tan Ca',
    );

    if (bioResult['success'] != true) {
      if (mounted) {
        final msg = bioResult['message'] ?? 'Xác thực vân tay không thành công';
        if (msg.contains('hủy')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppTheme.amber),
          );
        } else {
          ModernAnimatedDialogs.showSecurityWarning(
            context: context,
            title: bioResult['isBiometricChanged'] == true
                ? 'Cấu Hình Vân Tay Đã Đổi'
                : 'Cảnh Báo Bảo Mật',
            message: msg,
          );
        }
      }
      return;
    }

    setState(() => _isProcessing = true);

    final result = await _attendanceService.checkOut(
      userId: _currentUser!.id,
      checkOutTime: DateTime.now(),
      biometricToken: bioResult['biometricToken'],
      deviceId: bioResult['deviceId'],
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result['success'] == true) {
      final timeStr =
          DateFormat('HH:mm:ss - dd/MM/yyyy').format(DateTime.now());
      NotificationService.notifyAttendanceSuccess(
        isCheckIn: false,
        shiftName: shiftName,
        timeStr: timeStr,
      );
      await ModernAnimatedDialogs.showSuccessAttendance(
        context: context,
        title: 'Điểm Danh Tan Ca Thành Công!',
        employeeName: _currentUser!.fullName,
        timeString: timeStr,
        isCheckIn: false,
      );
      _loadData();
    } else {
      final msg = result['message'] ?? 'Check-out thất bại.';
      if (ApiClient.isNetworkError(msg)) {
        ModernAnimatedDialogs.showNoInternetDialog(context: context);
      } else {
        ModernAnimatedDialogs.showSecurityWarning(
          context: context,
          title: 'Điểm Danh Không Hợp Lệ',
          message: msg,
        );
      }
    }
  }

  Widget _buildTopGreetingBar(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final timeInMinutes = hour * 60 + minute;

    String greetingText;
    IconData greetingIcon;
    Color greetingColor;

    if (timeInMinutes >= 5 * 60 && timeInMinutes < 11 * 60) {
      greetingText = 'Chào buổi sáng';
      greetingIcon = Icons.wb_sunny_rounded;
      greetingColor = const Color(0xFFF59E0B); // Amber
    } else if (timeInMinutes >= 11 * 60 && timeInMinutes < 13 * 60 + 30) {
      greetingText = 'Chào buổi trưa';
      greetingIcon = Icons.wb_sunny_rounded;
      greetingColor = const Color(0xFFF97316); // Orange
    } else if (timeInMinutes >= 13 * 60 + 30 && timeInMinutes < 18 * 60) {
      greetingText = 'Chào buổi chiều';
      greetingIcon = Icons.wb_twilight_rounded;
      greetingColor = const Color(0xFF0EA5E9); // Sky
    } else {
      greetingText = 'Chào buổi tối';
      greetingIcon = Icons.nightlight_round;
      greetingColor = const Color(0xFF818CF8); // Indigo
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dynamic Greeting Capsule (Larger & Prominent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  greetingColor.withValues(alpha: 0.18),
                  greetingColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: greetingColor.withValues(alpha: 0.38),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: greetingColor.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(greetingIcon, size: 20, color: greetingColor),
                const SizedBox(width: 8),
                Text(
                  greetingText,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: greetingColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          // Workspace Status Chip (Thay thế chip ngày bị trùng lặp)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
              boxShadow: AppTheme.softShadow(context),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7.5,
                  height: 7.5,
                  decoration: BoxDecoration(
                    color: _isOffline ? AppTheme.rose : AppTheme.emerald,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Nova Corp',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = AppTheme.isDark(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final selectedMeta = _shiftCatalog.firstWhere(
      (s) => s['name'] == _selectedShift,
      orElse: () => _shiftCatalog.first,
    );
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final int earliestMins = selectedMeta['earliestMinutes'] as int;
    final int latestMins = selectedMeta['latestMinutes'] as int;
    final bool isShiftGateOpen =
        nowMins >= earliestMins && nowMins <= latestMins;
    final bool isAfterShiftGate = nowMins > latestMins;

    final bool hasCheckedIn = _todayRecord?.checkInTime != null;
    final bool hasCheckedOut = _todayRecord?.checkOutTime != null;
    final bool isWorkingShiftNow = hasCheckedIn && !hasCheckedOut;
    final bool canCheckInEveningOt = hasCheckedIn &&
        hasCheckedOut &&
        _todayRecord?.shiftName != 'Ca Tối (18:00 - 22:00)' &&
        _selectedShift == 'Ca Tối (18:00 - 22:00)';

    // Nút Check-in chỉ sáng và khả dụng khi cổng điểm danh của ca đang chọn ĐANG MỞ
    final bool canTriggerCheckIn = (
        (!hasCheckedIn && isShiftGateOpen) ||
        (canCheckInEveningOt && isShiftGateOpen)
    );

    String checkInSubtitle;
    if (canCheckInEveningOt) {
      checkInSubtitle = isShiftGateOpen
          ? 'Vào Ca Tối (Tăng ca)'
          : (isAfterShiftGate ? 'Hết giờ Ca Tối' : 'Chờ mở cổng tối');
    } else if (hasCheckedIn) {
      checkInSubtitle = 'Đã vào ca';
    } else {
      if (isShiftGateOpen) {
        checkInSubtitle = _selectedShift == 'Ca Tối (18:00 - 22:00)'
            ? 'Vào Ca Tối (Tăng ca)'
            : 'Chạm điểm danh';
      } else if (isAfterShiftGate) {
        checkInSubtitle = 'Cổng đã đóng';
      } else {
        checkInSubtitle = 'Chưa mở cổng';
      }
    }

    final bool isBioEnrolled = _currentUser?.isBiometricEnrolled == true;

    final int monthDays = _monthRecords
        .where((r) => r.checkInTime != null)
        .map((r) => r.attendanceDate.day)
        .toSet()
        .length;
    final double monthHours =
        _monthRecords.fold(0.0, (sum, r) => sum + r.totalWorkingHours);
    final double monthOtHours =
        _monthRecords.fold(0.0, (sum, r) => sum + r.overtimeHours);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            controller: _activeScrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 0. TOP GREETING HEADER BAR
                _buildTopGreetingBar(context),

                // 1. Executive Top Bar (Chạm vào tên/avatar chuyển ngay qua tab Cá nhân)
                Row(
                  children: [
                    Expanded(
                      child: BounceTap(
                        onTap: () {
                          if (widget.onNavigateToProfile != null) {
                            widget.onNavigateToProfile!();
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ProfileScreen()),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppTheme.primary, AppTheme.accent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  (_currentUser?.fullName.isNotEmpty ?? false)
                                      ? _currentUser!.fullName
                                          .trim()
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : 'N',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _currentUser?.fullName ?? "Nhân viên",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 18.5,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.textPrimary(context),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 12,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.business_center_rounded,
                                        size: 15,
                                        color: AppTheme.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          '${_currentUser?.position ?? "Nhân viên"} • ${_currentUser?.department ?? "Phòng ban"}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                AppTheme.textSecondary(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nút Chuông Thông Báo với Badge đỏ đếm số chưa đọc
                    ValueListenableBuilder<int>(
                      valueListenable: NotificationStore.unreadCountNotifier,
                      builder: (context, unreadCount, _) {
                        return BounceTap(
                          onTap: () => NotificationCenterSheet.show(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.surface(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border(context)),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  unreadCount > 0
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_none_rounded,
                                  size: 20,
                                  color: unreadCount > 0
                                      ? AppTheme.primary
                                      : AppTheme.textPrimary(context),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.rose,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppTheme.surface(context),
                                          width: 1.5,
                                        ),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    BounceTap(
                      onTap: () => AppTheme.toggleTheme(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border(context)),
                        ),
                        child: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          size: 20,
                          color: isDark
                              ? const Color(0xFFFBBF24)
                              : AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_smartReminder != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF38BDF8)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFF0284C7),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _smartReminder!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 2. Biometric Warning Banner (If Not Enrolled)
                if (!isBioEnrolled) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint_rounded,
                            color: AppTheme.amber, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chưa đăng ký vân tay',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              Text(
                                'Liên kết vân tay thiết bị để điểm danh nhanh',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isProcessing
                              ? null
                              : _handleEnrollBiometricNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.amber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Đăng ký',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_isOffline)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mất Kết Nối Mạng!',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Vui lòng kết nối Wi-Fi hoặc 4G/5G để điểm danh.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _checkNetworkStatus();
                            ModernAnimatedDialogs.showNoInternetDialog(
                                context: context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Chi tiết',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 3. MASTER HERO DASHBOARD CARD (Clock + Date + GPS + In/Out + Progress)
                ClockWidget(
                  checkInTime: _todayRecord?.checkInTime,
                  checkOutTime: _todayRecord?.checkOutTime,
                  completedHours: _todayRecord?.totalWorkingHours ?? 0.0,
                  shiftName: _todayRecord?.shiftName ?? _selectedShift,
                  locationStatus: _locationStatus,
                  proofImagePath: _todayRecord?.proofImagePath,
                  onTapProofImage: () {
                    if (_todayRecord?.proofImagePath == null) return;
                    final inStr = _todayRecord?.checkInTime != null
                        ? DateFormat('HH:mm:ss • dd/MM/yyyy')
                            .format(_todayRecord!.checkInTime!)
                        : 'N/A';
                    ModernAnimatedDialogs.showSelfieProofDialog(
                      context: context,
                      imageUrl: _todayRecord!.proofImagePath,
                      employeeName: _currentUser?.fullName ?? 'Nhân viên',
                      timeString: inStr,
                      shiftName: _todayRecord?.shiftName ?? _selectedShift,
                    );
                  },
                  onTapLocation: () async {
                    if (_locationStatus?.statusType ==
                        LocationStatusType.serviceDisabled) {
                      await LocationService.openLocationSettings();
                    } else if (_locationStatus?.statusType ==
                            LocationStatusType.permissionDenied ||
                        _locationStatus?.statusType ==
                            LocationStatusType.permissionDeniedForever ||
                        _locationStatus?.statusType ==
                            LocationStatusType.error) {
                      await LocationService.openAppSettings();
                    }
                    final loc =
                        await LocationService.checkGeofence(forceFresh: true);
                    if (!mounted) return;
                    setState(() => _locationStatus = loc);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.statusType == LocationStatusType.serviceDisabled
                              ? '⚠️ GPS đang tắt. Vui lòng bật Vị trí trong Cài đặt máy.'
                              : loc.isInside
                                  ? '📍 Vị trí hợp lệ: Đang ở khuôn viên công ty (Cách ~${loc.distanceMeters.round()}m).'
                                  : '⚠️ Đang cách trụ sở ~${(loc.distanceMeters / 1000).toStringAsFixed(1)}km (~${loc.distanceMeters.round()}m). Cần ở trong bán kính 400m để điểm danh.',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        backgroundColor: loc.isInside
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 4. SHIFT SELECTOR SECTION
                _buildShiftSelectorSection(
                  context: context,
                  isWorkingShiftNow: isWorkingShiftNow,
                ),
                const SizedBox(height: 16),

                // 5. ERGONOMIC ACTION BUTTONS (THUMB ZONE)
                _isProcessing
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        decoration: BoxDecoration(
                          color: AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppTheme.border(context)),
                        ),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                                color: AppTheme.primary),
                            const SizedBox(height: 12),
                            Text(
                              'Đang xác thực khóa sinh trắc học với máy chủ...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: AnimatedAttendanceButton(
                              title: 'VÀO CA',
                              subtitle: checkInSubtitle,
                              icon: Icons.login_rounded,
                              gradientColors: const [
                                AppTheme.emeraldDark,
                                AppTheme.emerald,
                              ],
                              isEnabled: canTriggerCheckIn,
                              onTap: canTriggerCheckIn ? _handleCheckIn : null,
                              onDisabledTap: () {
                                if (hasCheckedIn && !canCheckInEveningOt) {
                                  ModernAnimatedDialogs.showSecurityWarning(
                                    context: context,
                                    title: 'Đã Điểm Danh Vào Ca',
                                    message:
                                        'Bạn đã hoàn tất Check-in hôm nay. Khi hết ca làm việc, vui lòng bấm Check-out Tan Ca.',
                                  );
                                } else if (!isShiftGateOpen) {
                                  ModernAnimatedDialogs.showSecurityWarning(
                                    context: context,
                                    title: isAfterShiftGate
                                        ? 'Cổng Điểm Danh Đã Đóng'
                                        : 'Chưa Đến Giờ Mở Cổng',
                                    message: isAfterShiftGate
                                        ? 'Cổng Check-in của [$_selectedShift] đã đóng (khung giờ mở: ${selectedMeta['gateText']}).\n\nNếu bạn muốn điểm danh làm việc buổi tối, vui lòng chọn "Ca Tối (18:00 - 22:00)" ở phía trên.'
                                        : 'Cổng Check-in của [$_selectedShift] chỉ mở từ ${selectedMeta['gateText']}. Vui lòng quay lại vào đúng khung giờ.',
                                  );
                                }
                              },
                              isCheckIn: true,
                              isCompleted:
                                  hasCheckedIn && !canCheckInEveningOt,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: AnimatedAttendanceButton(
                              title: 'TAN CA',
                              subtitle: hasCheckedOut
                                  ? 'Đã hoàn tất'
                                  : (hasCheckedIn
                                      ? 'Chạm tan ca'
                                      : 'Chờ vào ca'),
                              icon: Icons.logout_rounded,
                              gradientColors: const [
                                AppTheme.roseDark,
                                AppTheme.rose,
                              ],
                              isEnabled: isWorkingShiftNow,
                              onTap:
                                  isWorkingShiftNow ? _handleCheckOut : null,
                              onDisabledTap: () {
                                if (!hasCheckedIn) {
                                  ModernAnimatedDialogs.showSecurityWarning(
                                    context: context,
                                    title: 'Chưa Vào Ca',
                                    message:
                                        'Bạn chưa điểm danh Vào Ca hôm nay nên chưa thể bấm Tan Ca.',
                                  );
                                } else if (hasCheckedOut) {
                                  ModernAnimatedDialogs.showSecurityWarning(
                                    context: context,
                                    title: 'Đã Hoàn Tất Ca Làm',
                                    message:
                                        'Bạn đã bấm tan ca và hoàn thành ca làm việc hôm nay.',
                                  );
                                }
                              },
                              isCheckIn: false,
                              isCompleted: hasCheckedOut,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 18),

                // 6. MONTHLY SUMMARY KPI CARD (Spacious & Zero Overflow)
                _buildMonthlySummaryCard(
                  context: context,
                  monthDays: monthDays,
                  monthHours: monthHours,
                  monthOtHours: monthOtHours,
                ),
                const SizedBox(height: 18),

                // 7. NAVIGATION TO HISTORY ("Xem lịch sử chấm công")
                BounceTap(
                  onTap: () {
                    if (widget.onNavigateToHistory != null) {
                      widget.onNavigateToHistory!();
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const HistoryScreen()),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border(context)),
                      boxShadow: AppTheme.softShadow(context),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: AppTheme.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xem lịch sử chấm công',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Bảng công chi tiết, giờ vào ra & ảnh chụp',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlySummaryCard({
    required BuildContext context,
    required int monthDays,
    required double monthHours,
    required double monthOtHours,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title on Left (Expanded) + Wrapped Button on Right
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.analytics_rounded,
                    size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Thống Kê Tháng ${DateTime.now().month}/${DateTime.now().year}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quy chuẩn: Thứ 2 – Thứ 7 (CN Nghỉ)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BounceTap(
                onTap: () => MonthlyWrappedScreen.show(
                  context,
                  year: DateTime.now().year,
                  month: DateTime.now().month,
                  records: _monthRecords,
                  employeeName: _currentUser?.fullName,
                  department: _currentUser?.department,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF7C3AED).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: Color(0xFFFDE047), size: 14),
                      SizedBox(width: 5),
                      Text(
                        'Wrapped',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3 Big Spacious Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildSpaciousStatTile(
                  context: context,
                  label: 'Ngày công',
                  value: '$monthDays/26',
                  unit: 'ngày',
                  subtext: 'Chuẩn 26 ngày',
                  icon: Icons.calendar_month_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSpaciousStatTile(
                  context: context,
                  label: 'Tổng giờ làm',
                  value: monthHours.toStringAsFixed(1),
                  unit: 'h',
                  subtext: 'Giờ thực tế',
                  icon: Icons.schedule_rounded,
                  color: AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSpaciousStatTile(
                  context: context,
                  label: 'Giờ tăng ca',
                  value: '+${monthOtHours.toStringAsFixed(1)}',
                  unit: 'h',
                  subtext: 'x1.5 / x2.0',
                  icon: Icons.bolt_rounded,
                  color: AppTheme.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpaciousStatTile({
    required BuildContext context,
    required String label,
    required String value,
    required String unit,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.elevated(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getShiftIcon(String shiftName) {
    final lower = shiftName.toLowerCase();
    if (lower.contains('chiều')) return Icons.wb_twilight_rounded;
    if (lower.contains('tối')) return Icons.nights_stay_rounded;
    if (lower.contains('sáng')) return Icons.wb_sunny_rounded;
    return Icons.business_center_rounded;
  }

  Color _getShiftColor(String shiftName) {
    final lower = shiftName.toLowerCase();
    if (lower.contains('chiều')) return const Color(0xFFF59E0B);
    if (lower.contains('tối')) return const Color(0xFF8B5CF6);
    if (lower.contains('sáng')) return const Color(0xFF0EA5E9);
    return AppTheme.primary;
  }

  String _formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _getShiftHoursSpan(Map<String, dynamic> meta) {
    final name = meta['name'] as String;
    if (name.contains('(')) {
      return name.substring(name.indexOf('(') + 1).replaceAll(')', '');
    }
    return '';
  }

  String _getShiftDurationText(Map<String, dynamic> meta) {
    final hoursText = meta['hoursText'] as String? ?? '';
    if (hoursText.contains('chuẩn ')) {
      return hoursText.substring(hoursText.indexOf('chuẩn ')).replaceAll(')', '');
    }
    if (hoursText.contains('tối đa ')) {
      return hoursText.substring(hoursText.indexOf('tối đa ')).replaceAll(')', '');
    }
    return 'Chuẩn 8 tiếng';
  }

  Widget _buildShiftSelectorSection({
    required BuildContext context,
    required bool isWorkingShiftNow,
  }) {
    final assigned =
        _currentUser?.assignedShift ?? 'Ca Hành Chính (08:00 - 17:00)';
    final isFlexible = assigned.toLowerCase().contains('xoay ca') ||
        assigned.toLowerCase().contains('linh hoạt');
    final isAssignedAfternoon = assigned.contains('Chiều');

    // Chỉ lấy các ca được quyền tham gia (ẩn hoàn toàn các ca bị khóa theo yêu cầu)
    final allowedShifts = _shiftCatalog.where((shift) {
      final name = shift['name'] as String;
      final isEveningShift = name == 'Ca Tối (18:00 - 22:00)';
      if (isFlexible) return true;
      if (isAssignedAfternoon) {
        return name == assigned;
      }
      return name == assigned || isEveningShift;
    }).toList();

    // Đảm bảo ca đang chọn nằm trong danh sách được phép
    if (!allowedShifts.any((s) => s['name'] == _selectedShift) &&
        allowedShifts.isNotEmpty) {
      _selectedShift = allowedShifts.first['name'] as String;
    }

    final selectedMeta = _shiftCatalog.firstWhere(
      (s) => s['name'] == _selectedShift,
      orElse: () => _shiftCatalog.first,
    );

    final shiftFullName = selectedMeta['name'] as String;
    final shiftMainTitle = shiftFullName.split(' (').first;
    final shiftColor = _getShiftColor(shiftFullName);
    final shiftIcon = _getShiftIcon(shiftFullName);
    final bool hasMultipleShifts = allowedShifts.length > 1;

    // Tính toán thời gian thực của cổng
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final int startMins = selectedMeta['startMinutes'] as int;
    final int endMins = selectedMeta['endMinutes'] as int;
    final int earliest = selectedMeta['earliestMinutes'] as int;
    final int latest = selectedMeta['latestMinutes'] as int;
    final String gateText = selectedMeta['gateText'] as String;

    final bool isOpen = nowMins >= earliest && nowMins <= latest;
    final bool isOnTime = nowMins <= startMins;
    final int lateMins = nowMins - startMins;

    final Color statusColor = !isOpen
        ? const Color(0xFF64748B)
        : (isOnTime ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final String statusHeadline = !isOpen
        ? 'Cổng điểm danh đang đóng'
        : (isOnTime
            ? 'Cổng đang mở • Đúng giờ'
            : 'Cổng đang mở • Đi trễ $lateMins phút');

    final IconData statusIcon = !isOpen
        ? Icons.lock_clock_rounded
        : (isOnTime ? Icons.check_circle_rounded : Icons.warning_amber_rounded);

    final bool isEveningShiftTime =
        !isAssignedAfternoon && nowMins >= 17 * 60 + 30 && nowMins <= 21 * 60;
    final bool canSwitchToEvening = !isOpen &&
        _selectedShift != 'Ca Tối (18:00 - 22:00)' &&
        isEveningShiftTime;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context), width: 1.2),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. HEADER ROW: TIÊU ĐỀ + NÚT ĐỔI CA / HUY HIỆU CA CHÍNH (Đã bỏ chữ "Quy định ca")
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: shiftColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CA LÀM VIỆC HÔM NAY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                if (hasMultipleShifts)
                  BounceTap(
                    onTap: !isWorkingShiftNow
                        ? () => _showShiftPickerSheet(
                            context, allowedShifts, isWorkingShiftNow)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: isWorkingShiftNow
                            ? AppTheme.border(context)
                            : AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isWorkingShiftNow
                            ? []
                            : [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Đổi ca',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isWorkingShiftNow
                                  ? AppTheme.textSecondary(context)
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: isWorkingShiftNow
                                ? AppTheme.textSecondary(context)
                                : Colors.white,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 13, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'Ca chính',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 2. MAIN SHIFT INFO (To rõ, thoáng đãng, không bao giờ bị '...')
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (hasMultipleShifts && !isWorkingShiftNow)
                  ? () => _showShiftPickerSheet(
                      context, allowedShifts, isWorkingShiftNow)
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: shiftColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: shiftColor.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(shiftIcon, color: shiftColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shiftMainTitle,
                            style: TextStyle(
                              fontSize: 18.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                _getShiftHoursSpan(selectedMeta),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: shiftColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '•  ${_getShiftDurationText(selectedMeta)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. INTEGRATED STATUS BANNER (Dải trạng thái thông minh)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 17, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusHeadline,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. THREE MILESTONE METRICS (Chữ to rõ, không lồng hộp con xám xịt)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                _buildMilestoneColumn(
                  context: context,
                  icon: Icons.meeting_room_outlined,
                  label: 'MỞ CỔNG',
                  value: gateText,
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppTheme.border(context),
                ),
                _buildMilestoneColumn(
                  context: context,
                  icon: Icons.timer_outlined,
                  label: 'ĐÚNG GIỜ',
                  value: 'Trước ${_formatMinutes(startMins)}',
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppTheme.border(context),
                ),
                _buildMilestoneColumn(
                  context: context,
                  icon: Icons.logout_rounded,
                  label: 'TAN CA',
                  value: _formatMinutes(endMins),
                ),
              ],
            ),
          ),

          if (canSwitchToEvening) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedShift = 'Ca Tối (18:00 - 22:00)');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.nightlight_round,
                          size: 15, color: AppTheme.primary),
                      SizedBox(width: 7),
                      Text(
                        'Đang mở Ca Tối (18:00 - 22:00) • Chạm để đổi ca',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestoneColumn({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12.5, color: AppTheme.textSecondary(context)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showShiftPickerSheet(
    BuildContext context,
    List<Map<String, dynamic>> allowedShifts,
    bool isWorkingShiftNow,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sync_alt_rounded,
                          size: 18, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn Ca Làm Việc',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chỉ hiển thị các ca được quyền điểm danh',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...allowedShifts.map((shift) {
                  final name = shift['name'] as String;
                  final isSelected = _selectedShift == name;
                  final color = _getShiftColor(name);
                  final icon = _getShiftIcon(name);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : AppTheme.elevated(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.border(context),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary(context),
                        ),
                      ),
                      subtitle: Text(
                        shift['hoursText'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppTheme.primary, size: 22)
                          : const Icon(Icons.radio_button_unchecked_rounded,
                              color: Colors.grey, size: 20),
                      onTap: () {
                        if (isWorkingShiftNow) {
                          Navigator.pop(ctx);
                          ModernAnimatedDialogs.showSecurityWarning(
                            context: context,
                            title: 'Đang Trong Ca Làm',
                            message:
                                'Bạn đang trong ca làm việc, không thể thay đổi ca cho đến khi hoàn tất bấm Tan Ca.',
                          );
                          return;
                        }
                        setState(() {
                          _selectedShift = name;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
