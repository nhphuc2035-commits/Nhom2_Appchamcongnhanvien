import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/location_service.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_animated_dialogs.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'salary_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  late final AnimationController _tabAnimController;
  late Animation<double> _fadeInAnim;
  late Animation<double> _fadeOutAnim;
  late Animation<Offset> _slideInAnim;
  late Animation<Offset> _slideOutAnim;
  final AttendanceService _attendanceService = AttendanceService();
  bool _isQuickProcessing = false;
  late final List<Widget> _screens;

  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final ScrollController _salaryScrollController = ScrollController();
  final ScrollController _profileScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      HomeScreen(
        scrollController: _homeScrollController,
        onNavigateToHistory: () => _onSelectTab(1),
        onNavigateToProfile: () => _onSelectTab(3),
      ),
      HistoryScreen(scrollController: _historyScrollController),
      SalaryScreen(scrollController: _salaryScrollController),
      ProfileScreen(scrollController: _profileScrollController),
    ];
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _setupTabAnimations(forward: true);
    _tabAnimController.value = 1.0;
  }

  void _setupTabAnimations({required bool forward}) {
    final curved = CurvedAnimation(
      parent: _tabAnimController,
      curve: Curves.easeOutCubic,
    );
    _fadeInAnim = curved;
    _fadeOutAnim = Tween<double>(begin: 1.0, end: 0.0).animate(curved);
    _slideInAnim = Tween<Offset>(
      begin: Offset(forward ? 0.08 : -0.08, 0.0),
      end: Offset.zero,
    ).animate(curved);
    _slideOutAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(forward ? -0.05 : 0.05, 0.0),
    ).animate(curved);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabAnimController.dispose();
    _homeScrollController.dispose();
    _historyScrollController.dispose();
    _salaryScrollController.dispose();
    _profileScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBiometricIntegrityOnResume();
    }
  }

  Future<void> _checkBiometricIntegrityOnResume() async {
    // Luôn tự động làm mới trạng thái cảm biến, tuyệt đối không hiện popup cảnh báo chặn người dùng
    await BiometricService.resetBiometricDetector();
  }

  void _scrollToTop(int index) {
    ScrollController? ctrl;
    switch (index) {
      case 0:
        ctrl = _homeScrollController;
        break;
      case 1:
        ctrl = _historyScrollController;
        break;
      case 2:
        ctrl = _salaryScrollController;
        break;
      case 3:
        ctrl = _profileScrollController;
        break;
    }
    if (ctrl != null && ctrl.hasClients) {
      if (ctrl.offset > 0) {
        ctrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _onSelectTab(int index) {
    if (_currentIndex == index) {
      // Chạm vào tab đang hoạt động: Đưa mượt về đầu trang
      HapticFeedback.selectionClick();
      _scrollToTop(index);
      return;
    }
    HapticFeedback.selectionClick();
    final forward = index > _currentIndex;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
      _setupTabAnimations(forward: forward);
    });
    _tabAnimController.forward(from: 0.0);
    // Khi load chuyển trang, cũng đồng thời tự động đưa về đầu trang
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTop(index);
    });
  }

  /// Nút Trung Tâm: Mở Bảng Chấm Công Nhanh tức thời (Phản hồi 0ms ngay lập tức)
  void _handleCenterPunchAction() {
    HapticFeedback.selectionClick();

    if (!NetworkService.isOnline) {
      ModernAnimatedDialogs.showNoInternetDialog(context: context);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _QuickAttendanceSheet(
        attendanceService: _attendanceService,
        onExecute: (isCheckIn) async {
          Navigator.of(ctx).pop();
          await _executeQuickAttendance(isCheckIn: isCheckIn);
        },
        onGoHome: () {
          Navigator.of(ctx).pop();
          _onSelectTab(0);
        },
      ),
    );
  }

  /// Quy trình thực thi Chấm Công tức thì
  Future<void> _executeQuickAttendance({required bool isCheckIn}) async {
    final user =
        AuthService.currentUser ?? await AuthService.fetchUserProfile();
    if (user == null || !mounted) return;

    // 0. Kiểm tra Radar GPS trước khi làm bất kỳ thao tác nào (phản hồi siêu tốc <10ms)
    final loc = await LocationService.checkGeofence();
    if (!loc.isInside) {
      if (!mounted) return;
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

    setState(() => _isQuickProcessing = true);

    // 1. Chụp ảnh Selfie nếu là vào ca
    String? proofBase64;
    if (isCheckIn) {
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
        debugPrint('Quick selfie fallback: $e');
      }
    }

    // 2. Quét vân tay sinh trắc học
    final bioResult = await BiometricService.authenticateAndGetToken(
      userId: user.id,
      reason: isCheckIn
          ? 'Quét vân tay chính chủ để Điểm Danh Vào Ca'
          : 'Quét vân tay chính chủ để Điểm Danh Tan Ca',
    );

    if (bioResult['success'] != true) {
      if (mounted) {
        setState(() => _isQuickProcessing = false);
        final msg = bioResult['message'] ?? 'Xác thực vân tay không thành công.';
        if (!msg.contains('hủy')) {
          ModernAnimatedDialogs.showSecurityWarning(
            context: context,
            title: 'Cảnh Báo Bảo Mật',
            message: msg,
          );
        }
      }
      return;
    }

    // 3. Gửi lên Server WebAPI
    final res = isCheckIn
        ? await _attendanceService.checkIn(
            userId: user.id,
            checkInTime: DateTime.now(),
            shiftName: user.assignedShift,
            biometricToken: bioResult['biometricToken'],
            deviceId: bioResult['deviceId'],
            proofImageBase64: proofBase64,
          )
        : await _attendanceService.checkOut(
            userId: user.id,
            checkOutTime: DateTime.now(),
            biometricToken: bioResult['biometricToken'],
            deviceId: bioResult['deviceId'],
          );

    if (!mounted) return;
    setState(() => _isQuickProcessing = false);

    if (res['success'] == true) {
      final timeStr = DateFormat('HH:mm:ss - dd/MM/yyyy').format(DateTime.now());
      await ModernAnimatedDialogs.showSuccessAttendance(
        context: context,
        title: isCheckIn ? 'Điểm Danh Vào Ca Thành Công!' : 'Điểm Danh Tan Ca Thành Công!',
        employeeName: user.fullName,
        timeString: timeStr,
        isCheckIn: isCheckIn,
      );
      // Chuyển về Home và refresh
      _onSelectTab(0);
    } else {
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Điểm Danh Không Hợp Lệ',
        message: res['message'] ?? 'Thao tác thất bại.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          // 1. Content layer (GPU-accelerated native compositor transitions - 120fps fluid)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _tabAnimController,
              builder: (context, _) {
                final isAnimating = _tabAnimController.isAnimating;
                return Stack(
                  fit: StackFit.expand,
                  children: List.generate(_screens.length, (i) {
                    final isCurrent = i == _currentIndex;
                    final isPrevious = i == _previousIndex;

                    if (!isAnimating) {
                      return Offstage(
                        offstage: !isCurrent,
                        child: TickerMode(
                          enabled: isCurrent,
                          child: RepaintBoundary(child: _screens[i]),
                        ),
                      );
                    }

                    if (isCurrent) {
                      return SlideTransition(
                        position: _slideInAnim,
                        child: FadeTransition(
                          opacity: _fadeInAnim,
                          child: RepaintBoundary(child: _screens[i]),
                        ),
                      );
                    } else if (isPrevious) {
                      return IgnorePointer(
                        ignoring: true,
                        child: SlideTransition(
                          position: _slideOutAnim,
                          child: FadeTransition(
                            opacity: _fadeOutAnim,
                            child: RepaintBoundary(child: _screens[i]),
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  }),
                );
              },
            ),
          ),

          // 2. Truly Floating Glassmorphism Capsule Bar
          Positioned(
            left: 18,
            right: 18,
            bottom: bottomInset > 0 ? bottomInset + 8 : 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E2533) : Colors.white)
                        .withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(44),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 1. Home Tab
                      _buildCapsuleNavItem(
                        index: 0,
                        icon: Icons.home_rounded,
                        label: 'Trang chủ',
                        isDark: isDark,
                      ),

                      // 2. History Tab
                      _buildCapsuleNavItem(
                        index: 1,
                        icon: Icons.history_rounded,
                        label: 'Lịch sử',
                        isDark: isDark,
                      ),

                      // 3. Center Punch Hero Button (In-frame, perfectly vertically centered)
                      GestureDetector(
                        onTap: _handleCenterPunchAction,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.how_to_reg_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          ),
                        ),
                      ),

                      // 4. Salary Tab
                      _buildCapsuleNavItem(
                        index: 2,
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Bảng lương',
                        isDark: isDark,
                      ),

                      // 5. Profile Tab
                      _buildCapsuleNavItem(
                        index: 3,
                        icon: Icons.person_rounded,
                        label: 'Cá nhân',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Loading Overlay during Quick Attendance execution
          if (_isQuickProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: Card(
                    color: Color(0xFF1E2533),
                    elevation: 12,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.8,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Đang xác thực điểm danh...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCapsuleNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final bool isSelected = _currentIndex == index;
    final activeColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onSelectTab(index),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              child: Icon(
                icon,
                size: 27, // Increased icon size for perfect visual balance
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bảng Chấm Công Nhanh (Bottom Sheet mở tức thời 0ms, nạp dữ liệu GPS và ca làm việc bất đồng bộ)
class _QuickAttendanceSheet extends StatefulWidget {
  final AttendanceService attendanceService;
  final Function(bool isCheckIn) onExecute;
  final VoidCallback onGoHome;

  const _QuickAttendanceSheet({
    required this.attendanceService,
    required this.onExecute,
    required this.onGoHome,
  });

  @override
  State<_QuickAttendanceSheet> createState() => _QuickAttendanceSheetState();
}

class _QuickAttendanceSheetState extends State<_QuickAttendanceSheet> {
  bool _isLoading = true;
  AttendanceRecord? _todayRecord;
  LocationCheckResult? _locationResult;
  String _employeeName = '';
  String _shiftName = 'Ca Hành Chính (08:00 - 17:00)';

  @override
  void initState() {
    super.initState();
    // Nạp ngay tức thời thông tin có sẵn trong bộ nhớ đệm (0ms phản hồi)
    final cached = AuthService.currentUser;
    if (cached != null) {
      _employeeName = cached.fullName;
      _shiftName = cached.assignedShift ?? 'Ca Hành Chính (08:00 - 17:00)';
    }
    _loadSheetData();
  }

  Future<void> _loadSheetData() async {
    try {
      final user = AuthService.currentUser ?? await AuthService.fetchUserProfile();
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final results = await Future.wait([
        widget.attendanceService.getMyHistory(fromDate: monthStart),
        LocationService.checkGeofence(),
      ]);

      final history = results[0] as List<AttendanceRecord>;
      final loc = results[1] as LocationCheckResult;

      AttendanceRecord? todayRec;
      final today = DateTime(now.year, now.month, now.day);
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

      if (mounted) {
        setState(() {
          _employeeName = user?.fullName ?? _employeeName;
          _shiftName = todayRec?.shiftName ??
              user?.assignedShift ??
              _shiftName;
          _todayRecord = todayRec;
          _locationResult = loc;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _triggerInstantWarning(LocationCheckResult loc) {
    Navigator.of(context).pop();
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bgColor = isDark ? const Color(0xFF131B2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final bool isCheckedIn = _todayRecord != null;
    final bool isCompleted = isCheckedIn && _todayRecord!.checkOutTime != null;
    final bool isWorking = isCheckedIn && !isCompleted;
    final bool canPunchIn = !isCheckedIn;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 36,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 18),

          // Header hiện đại - Không bao giờ bị cắt chữ "..."
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Chấm Công Nhanh',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'RADAR LIVE',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _employeeName.isNotEmpty ? _employeeName : 'Đang đồng bộ hồ sơ...',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.88),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: subColor, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Khung thông tin Ca làm việc (Hiển thị đầy đủ, sắc nét, không bị "...")
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _shiftName,
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : (isWorking
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCompleted ? 'Đã tan ca' : (isWorking ? 'Đang trong ca' : 'Chưa vào ca'),
                    style: TextStyle(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : (isWorking ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6)),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Content body
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Đang kết nối vệ tinh GPS & dữ liệu ca...',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 1. Radar GPS Card thiết kế cao cấp
            _buildRadarBadge(isDark),

            const SizedBox(height: 16),

            // 2. Attendance Action Button or Completed Card
            if (isCompleted)
              _buildCompletedCard(isDark)
            else if (isWorking)
              _buildActionButton(
                label: 'ĐIỂM DANH TAN CA',
                sublabel: 'Xác thực vân tay chính chủ để chốt giờ làm',
                icon: Icons.logout_rounded,
                gradientColors: const [Color(0xFFEA580C), Color(0xFFC2410C)],
                onTap: () {
                  if (_locationResult != null && !_locationResult!.isInside) {
                    _triggerInstantWarning(_locationResult!);
                    return;
                  }
                  widget.onExecute(false);
                },
              )
            else if (canPunchIn)
              _buildActionButton(
                label: 'ĐIỂM DANH VÀO CA',
                sublabel: 'Chụp ảnh selfie minh chứng + Xác thực vân tay',
                icon: Icons.login_rounded,
                gradientColors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                onTap: () {
                  if (_locationResult != null && !_locationResult!.isInside) {
                    _triggerInstantWarning(_locationResult!);
                    return;
                  }
                  widget.onExecute(true);
                },
              ),

            const SizedBox(height: 10),

            // 3. Shortcut to Full Home
            TextButton(
              onPressed: widget.onGoHome,
              child: Text(
                'Mở toàn bộ bảng điều khiển tại Trang chủ',
                style: TextStyle(
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadarBadge(bool isDark) {
    final loc = _locationResult;
    final bool isInside = loc?.isInside == true;

    final Color badgeBg = isInside
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.28) : const Color(0xFFFFF7ED));

    final Color borderColor = isInside
        ? (isDark ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFFA7F3D0))
        : (isDark ? const Color(0xFFEA580C).withValues(alpha: 0.45) : const Color(0xFFFED7AA));

    final Color accentColor = isInside ? const Color(0xFF10B981) : const Color(0xFFF97316);
    final Color textColor = isInside
        ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46))
        : (isDark ? const Color(0xFFFFEDD5) : const Color(0xFF9A3412));

    String distancePill = '≤ 100m';
    if (!isInside && loc != null) {
      if (loc.distanceMeters >= 1000) {
        distancePill = '${(loc.distanceMeters / 1000).toStringAsFixed(1)} km';
      } else {
        distancePill = '${loc.distanceMeters.toStringAsFixed(0)} m';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Icon(
              isInside ? Icons.radar_rounded : Icons.location_off_rounded,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isInside
                            ? 'Radar GPS: Trong phạm vi trụ sở'
                            : 'Radar GPS: Ngoài phạm vi điểm danh',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        distancePill,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isInside
                      ? 'Đã xác thực tọa độ tại Trụ sở Nova Corp. Đủ điều kiện điểm danh ngay.'
                      : (loc?.message ??
                          'Bạn đang ở ngoài phạm vi văn phòng công ty (cho phép tối đa 100m).'),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String sublabel,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedCard(bool isDark) {
    final rec = _todayRecord!;
    final inStr = rec.checkInTime != null
        ? DateFormat('HH:mm').format(rec.checkInTime!)
        : '--:--';
    final outStr = rec.checkOutTime != null
        ? DateFormat('HH:mm').format(rec.checkOutTime!)
        : '--:--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đã Hoàn Thành Ca Hôm Nay',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${rec.totalWorkingHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                'Vào ca: $inStr',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '•',
                style: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
              ),
              Text(
                'Tan ca: $outStr',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
