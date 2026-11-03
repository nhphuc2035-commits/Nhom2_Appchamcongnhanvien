import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_animated_dialogs.dart';
import '../widgets/staggered_animations.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ScrollController? scrollController;

  const ProfileScreen({
    super.key,
    this.scrollController,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  ScrollController? _internalScrollController;
  ScrollController get _activeScrollController =>
      widget.scrollController ??
      (_internalScrollController ??= ScrollController());

  UserModel? _user;
  bool _isLoading = true;
  bool _isEnrollingBio = false;
  String _bioHwState = 'VALID';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _internalScrollController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBioChange();
    }
  }

  Future<void> _checkBioChange() async {
    final hwState = await BiometricService.getBiometricHardwareState();
    if (mounted && hwState != _bioHwState) {
      setState(() => _bioHwState = hwState);
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    final user = await AuthService.fetchUserProfile();
    final hwState = await BiometricService.getBiometricHardwareState();
    if (mounted) {
      setState(() {
        _user = user;
        _bioHwState = hwState;
        _isLoading = false;
      });
    }
  }

  Future<bool> _showPasswordConfirmationDialog({
    required String title,
    required String message,
  }) async {
    final pwdCtrl = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface(ctx),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_person_rounded, color: AppTheme.amber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(ctx),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(ctx), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pwdCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Nhập mật khẩu tài khoản',
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      filled: true,
                      fillColor: AppTheme.elevated(ctx),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(ctx, false),
                  child: Text('Hủy', style: TextStyle(color: AppTheme.textSecondary(ctx))),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final pwd = pwdCtrl.text.trim();
                          if (pwd.isEmpty) {
                            setDialogState(() => errorText = 'Vui lòng nhập mật khẩu.');
                            return;
                          }
                          setDialogState(() {
                            isVerifying = true;
                            errorText = null;
                          });
                          final loginRes = await AuthService.login(_user!.username, pwd);
                          if (loginRes['success'] == true) {
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } else {
                            setDialogState(() {
                              isVerifying = false;
                              errorText = 'Mật khẩu không chính xác.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Xác Nhận', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    return result == true;
  }

  Future<void> _enrollBiometrics() async {
    if (_user == null) return;

    // Luôn đồng bộ hồ sơ mới nhất từ server trước khi kiểm tra (phát hiện nếu vừa được Admin reset)
    final freshUser = await AuthService.fetchUserProfile();
    if (freshUser != null) {
      setState(() => _user = freshUser);
    }

    // 0. PRE-CHECK: Kiểm tra xem điện thoại này đã được liên kết với nhân viên nào khác chưa
    final preCheck = await BiometricService.checkDeviceOwnership(
      currentUserId: _user!.id,
      currentUserName: _user!.fullName,
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

    if (!mounted) return;

    if (_bioHwState == 'NO_HARDWARE') {
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Không Có Cảm Biến',
        message:
            'Thiết bị này không có phần cứng cảm biến vân tay.\n\nBạn có thể điểm danh bằng phương thức Chụp ảnh Selfie và Định vị GPS tại Trang chủ.',
      );
      return;
    }

    if (_bioHwState == 'NONE_ENROLLED') {
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Chưa Cài Đặt Vân Tay',
        message:
            'Điện thoại hiện không có dấu vân tay nào được lưu trong máy.\n\nVui lòng vào mục Cài đặt của điện thoại -> Bảo mật -> Đăng ký ít nhất 1 dấu vân tay rồi quay lại ứng dụng.',
      );
      return;
    }

    // Chỉ yêu cầu mật khẩu khi cập nhật lại thủ công. Nếu đổi vân tay máy hoặc Admin reset, cho phép quét ngón tay mới trực tiếp
    if (_user?.isBiometricEnrolled == true && _bioHwState != 'CHANGED') {
      final confirmed = await _showPasswordConfirmationDialog(
        title: 'Xác Minh Chính Chủ',
        message:
            'Để cập nhật hoặc đồng bộ lại dấu vân tay vào hồ sơ, vui lòng nhập Mật khẩu tài khoản của bạn:',
      );
      if (!confirmed) return;
    }

    setState(() => _isEnrollingBio = true);

    final bioResult = await BiometricService.authenticateAndGetToken(
      userId: _user!.id,
      reason: 'Quét vân tay để liên kết hồ sơ chống gian lận điểm danh',
      forceReEnroll: true,
    );

    if (bioResult['success'] == true) {
      final srvResult = await BiometricService.enrollWithServer(
        userId: _user!.id,
        biometricToken: bioResult['biometricToken'],
        deviceId: bioResult['deviceId'],
      );

      if (mounted) {
        if (srvResult['success'] == true) {
          setState(() => _bioHwState = 'VALID');
          await ModernAnimatedDialogs.showSuccessBiometric(
            context: context,
            title: 'Liên Kết Vân Tay Thành Công!',
            employeeName: _user!.fullName,
            timeString:
                DateFormat('HH:mm:ss - dd/MM/yyyy').format(DateTime.now()),
            statusText: 'Đã Đồng Bộ Vân Tay Chính Chủ',
          );
        } else {
          final msg = srvResult['message'] ?? 'Không thể liên kết thiết bị.';
          if (ApiClient.isNetworkError(msg)) {
            ModernAnimatedDialogs.showNoInternetDialog(context: context);
          } else {
            ModernAnimatedDialogs.showSecurityWarning(
              context: context,
              title: 'Liên Kết Thất Bại',
              message: msg,
            );
          }
        }
        await _loadUserProfile();
      }
    } else if (mounted) {
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Cảnh Báo Sinh Trắc Học',
        message: bioResult['message'] ?? 'Xác thực vân tay không thành công.',
      );
    }

    if (mounted) setState(() => _isEnrollingBio = false);
  }

  Future<void> _showEditPersonalInfoModal() async {
    if (_user == null) return;

    final phoneCtrl = TextEditingController(text: _user?.phoneNumber ?? '');
    final cccdCtrl = TextEditingController(text: _user?.citizenId ?? '');
    final addrCtrl = TextEditingController(text: _user?.address ?? '');
    DateTime? selectedDob = _user?.dateOfBirth;
    String selectedGender =
        (_user?.gender == 'Nữ' || _user?.gender == 'Khác')
            ? _user!.gender!
            : 'Nam';
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                decoration: BoxDecoration(
                  color: AppTheme.surface(ctx),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: AppTheme.border(ctx)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary(ctx)
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cập nhật thông tin cá nhân',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary(ctx),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chức vụ, Phòng ban và Đơn giá lương do Phòng Nhân sự (Admin) cấp phép.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary(ctx),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: selectedDob ?? DateTime(1998, 1, 1),
                                    firstDate: DateTime(1950),
                                    lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setSheetState(() => selectedDob = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.elevated(ctx),
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: AppTheme.border(ctx)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ngày/tháng/năm sinh',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(ctx),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.cake_outlined,
                                            size: 16, color: AppTheme.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          selectedDob != null
                                              ? DateFormat('dd/MM/yyyy')
                                                  .format(selectedDob!)
                                              : 'Chọn ngày sinh',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary(ctx),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.elevated(ctx),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: AppTheme.border(ctx)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedGender,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Nam', child: Text('Giới tính: Nam')),
                                    DropdownMenuItem(
                                        value: 'Nữ', child: Text('Giới tính: Nữ')),
                                    DropdownMenuItem(
                                        value: 'Khác',
                                        child: Text('Giới tính: Khác')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setSheetState(
                                          () => selectedGender = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSheetInput(
                        ctx,
                        controller: cccdCtrl,
                        label: 'Số CCCD / CMND (12 chữ số)',
                        icon: Icons.credit_card_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildSheetInput(
                        ctx,
                        controller: phoneCtrl,
                        label: 'Số điện thoại liên hệ',
                        icon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildSheetInput(
                        ctx,
                        controller: addrCtrl,
                        label: 'Địa chỉ thường trú / liên hệ',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setSheetState(() => isSaving = true);
                                      final res =
                                          await AuthService.updateMyProfile(
                                        phoneNumber: phoneCtrl.text.trim(),
                                        dateOfBirth: selectedDob,
                                        gender: selectedGender,
                                        citizenId: cccdCtrl.text.trim(),
                                        address: addrCtrl.text.trim(),
                                      );
                                      if (!ctx.mounted) return;
                                      setSheetState(() => isSaving = false);
                                      if (res['success'] == true) {
                                        Navigator.pop(ctx);
                                        await _loadUserProfile();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Đã cập nhật thông tin hồ sơ cá nhân!'),
                                            backgroundColor: AppTheme.emerald,
                                          ),
                                        );
                                      } else {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(res['message'] ??
                                                'Cập nhật thất bại'),
                                            backgroundColor: AppTheme.rose,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Lưu cập nhật',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetInput(
    BuildContext ctx, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 13.5, color: AppTheme.textPrimary(ctx)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(fontSize: 12, color: AppTheme.textSecondary(ctx)),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.primary),
        filled: true,
        fillColor: AppTheme.elevated(ctx),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border(ctx)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border(ctx)),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await ModernAnimatedDialogs.showConfirmAction(
      context: context,
      title: 'Xác Nhận Đăng Xuất',
      message: 'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng điểm danh?',
      confirmText: 'Đăng Xuất',
      confirmColor: AppTheme.rose,
      icon: Icons.logout_rounded,
    );

    if (confirm == true && mounted) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = AppTheme.isDark(context);
    final currencyFmt = NumberFormat('#,###', 'vi_VN');
    final dateFmt = DateFormat('dd/MM/yyyy');

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final bool isBioEnrolled = _user?.isBiometricEnrolled == true;
    final String dobStr = _user?.dateOfBirth != null
        ? dateFmt.format(_user!.dateOfBirth!)
        : 'Chưa cập nhật';
    final String hireStr = _user?.hireDate != null
        ? dateFmt.format(_user!.hireDate!)
        : 'Chưa cập nhật';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _loadUserProfile,
          child: SingleChildScrollView(
            controller: _activeScrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                StaggeredFadeSlide(
                  index: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hồ Sơ Nhân Sự',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Thông tin cá nhân, chức vụ, ca làm việc & bảo mật',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Profile Hero Card
                StaggeredFadeSlide(
                  index: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 22, horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border(context)),
                      boxShadow: AppTheme.softShadow(context),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (_user?.fullName.isNotEmpty ?? false)
                                  ? _user!.fullName
                                      .trim()
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : 'N',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _user?.fullName ?? 'Nhân viên',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_user?.position ?? "Nhân viên chính thức"} • ${_user?.department ?? "Phòng ban"}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 14, color: AppTheme.emerald),
                              SizedBox(width: 5),
                              Text(
                                'Tài khoản nhân sự đang hoạt động',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.emerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Biometric Security Card
                StaggeredFadeSlide(
                  index: 2,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border(context)),
                      boxShadow: AppTheme.softShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                color: AppTheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Định Danh Vân Tay Chống Gian Lận',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                  Text(
                                    'Bảo vệ tài khoản và xác thực chấm công chính chủ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Builder(
                          builder: (ctx) {
                            final isNoHw = _bioHwState == 'NO_HARDWARE';
                            final isNoneEnrolled = _bioHwState == 'NONE_ENROLLED';
                            final isChanged = _bioHwState == 'CHANGED';

                            Color cardColor;
                            Color borderColor;
                            Color textColor;
                            IconData cardIcon;
                            String cardText;
                            String btnText;
                            Color btnColor;
                            IconData btnIcon;

                            if (isNoHw) {
                              cardColor = AppTheme.textSecondary(ctx).withValues(alpha: 0.08);
                              borderColor = AppTheme.border(ctx);
                              textColor = AppTheme.textSecondary(ctx);
                              cardIcon = Icons.phonelink_erase_rounded;
                              cardText =
                                  'Thiết bị không có cảm biến vân tay phần cứng.\nHệ thống hỗ trợ điểm danh bằng GPS & Ảnh Selfie.';
                              btnText = 'Điểm Danh Bằng GPS & Selfie Tại Trang Chủ';
                              btnColor = AppTheme.primary;
                              btnIcon = Icons.camera_alt_rounded;
                            } else if (isNoneEnrolled) {
                              cardColor = AppTheme.rose.withValues(alpha: 0.12);
                              borderColor = AppTheme.rose.withValues(alpha: 0.4);
                              textColor = AppTheme.rose;
                              cardIcon = Icons.no_accounts_rounded;
                              cardText = isBioEnrolled
                                  ? 'CẢNH BÁO: Toàn bộ vân tay trên máy đã bị xóa sạch! Vui lòng cài lại vân tay trong Cài đặt máy.'
                                  : 'Điện thoại chưa cài đặt vân tay nào. Vui lòng vào Cài đặt máy để thêm vân tay trước khi liên kết.';
                              btnText = isBioEnrolled
                                  ? 'Xác Minh Mật Khẩu & Đồng Bộ Lại'
                                  : 'Cài Đặt Máy Thêm Vân Tay Trước';
                              btnColor = AppTheme.rose;
                              btnIcon = Icons.fingerprint_rounded;
                            } else if (isChanged) {
                              cardColor = AppTheme.amber.withValues(alpha: 0.12);
                              borderColor = AppTheme.amber.withValues(alpha: 0.4);
                              textColor = AppTheme.amber;
                              cardIcon = Icons.fingerprint_rounded;
                              cardText =
                                  'Phát hiện cấu hình vân tay trên máy đã cập nhật. Bấm nút bên dưới để quét ngón tay mới.';
                              btnText = 'Đồng Bộ Ngón Tay Mới Ngay';
                              btnColor = AppTheme.amber;
                              btnIcon = Icons.fingerprint_rounded;
                            } else {
                              // VALID
                              cardColor = (isBioEnrolled ? AppTheme.emerald : AppTheme.amber)
                                  .withValues(alpha: 0.12);
                              borderColor = (isBioEnrolled ? AppTheme.emerald : AppTheme.amber)
                                  .withValues(alpha: 0.35);
                              textColor = isBioEnrolled ? AppTheme.emerald : AppTheme.amber;
                              cardIcon = isBioEnrolled
                                  ? Icons.shield_rounded
                                  : Icons.warning_amber_rounded;
                              cardText = isBioEnrolled
                                  ? 'Đã đăng ký và liên kết vân tay chính chủ với máy chủ'
                                  : 'Chưa liên kết vân tay với hồ sơ nhân viên trên máy chủ';
                              btnText = isBioEnrolled
                                  ? 'Xác Thực Lại / Đồng Bộ Khóa Vân Tay'
                                  : 'Đăng Ký Vân Tay Máy Này Ngay';
                              btnColor = isBioEnrolled ? AppTheme.emerald : AppTheme.primary;
                              btnIcon = Icons.fingerprint_rounded;
                            }

                            return Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(cardIcon, color: textColor, size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          cardText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isEnrollingBio ? null : _enrollBiometrics,
                                    icon: _isEnrollingBio
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(btnIcon, color: Colors.white, size: 18),
                                    label: Text(
                                      _isEnrollingBio ? 'Đang xác thực vân tay...' : btnText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: btnColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Personal Profile Details (Họ tên, Ngày sinh, Giới tính, CCCD, SĐT, Email, Địa chỉ)
                StaggeredFadeSlide(
                  index: 3,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border(context)),
                      boxShadow: AppTheme.softShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Thông tin lý lịch cá nhân',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BounceTap(
                              onTap: _showEditPersonalInfoModal,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_outlined,
                                        size: 14, color: AppTheme.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Cập nhật',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoTile(
                          context,
                          'Họ và tên nhân viên',
                          _user?.fullName ?? '',
                          Icons.badge_outlined,
                        ),
                        Divider(height: 18, color: AppTheme.border(context)),
                        _buildInfoTile(
                          context,
                          'Ngày/tháng/năm sinh & Giới tính',
                          '$dobStr  •  Giới tính: ${_user?.gender ?? "Nam"}',
                          Icons.cake_outlined,
                        ),
                        Divider(height: 18, color: AppTheme.border(context)),
                        _buildInfoTile(
                          context,
                          'Số CCCD / CMND định danh',
                          _user?.citizenId ?? 'Chưa cập nhật',
                          Icons.credit_card_rounded,
                        ),
                        Divider(height: 18, color: AppTheme.border(context)),
                        _buildInfoTile(
                          context,
                          'Số điện thoại liên hệ',
                          _user?.phoneNumber ?? 'Chưa cập nhật',
                          Icons.phone_outlined,
                        ),
                        Divider(height: 18, color: AppTheme.border(context)),
                        _buildInfoTile(
                          context,
                          'Email nhận báo cáo & phiếu lương',
                          _user?.email ?? '',
                          Icons.alternate_email_rounded,
                        ),
                        Divider(height: 18, color: AppTheme.border(context)),
                        _buildInfoTile(
                          context,
                          'Địa chỉ thường trú / liên hệ',
                          _user?.address ?? 'Chưa cập nhật',
                          Icons.location_on_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Company Job, Position & Salary Configuration Card
                StaggeredFadeSlide(
                  index: 4,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border(context)),
                      boxShadow: AppTheme.softShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chức vụ & Định mức lương (Do Admin cấp)',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoTile(
                          context,
                          'Phòng ban & Chức vụ hiện tại',
                          '${_user?.position ?? "Nhân viên chính thức"} (${_user?.department ?? "Phòng ban"})',
                          Icons.business_center_outlined,
                        ),
                        Divider(height: 18, color: AppTheme.border(context)),
                        _buildInfoTile(
                          context,
                          'Ca làm việc được Admin phân công',
                          _user?.assignedShift ?? 'Ca Hành Chính (08:00 - 17:00)',
                          Icons.schedule_rounded,
                        ),
                        Divider(height: 18, color: AppTheme.border(context)),
                        _buildInfoTile(
                          context,
                          'Đơn giá lương theo chức vụ & Tăng ca',
                          '${currencyFmt.format(_user?.currentHourlyRate ?? 55000)} đ/giờ  •  Tăng ca x${_user?.overtimeRateMultiplier ?? 1.5}',
                          Icons.payments_outlined,
                        ),
                        Divider(height: 18, color: AppTheme.border(context)),
                        _buildInfoTile(
                          context,
                          'Ngày vào làm chính thức',
                          hireStr,
                          Icons.event_available_outlined,
                        ),
                        Divider(height: 18, color: AppTheme.border(context)),
                        _buildInfoTile(
                          context,
                          'Tài khoản đăng nhập & Mã nhân sự',
                          '@${_user?.username ?? ""} (${_user?.id ?? ""})',
                          Icons.person_outline_rounded,
                          allowCopy: true,
                          copyText: _user?.id,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Settings & System Utilities
                StaggeredFadeSlide(
                  index: 5,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border(context)),
                      boxShadow: AppTheme.softShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cài đặt & Tiện ích ứng dụng',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildActionRow(
                          context: context,
                          icon: isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          iconColor: isDark
                              ? const Color(0xFFFBBF24)
                              : AppTheme.primary,
                          title: 'Giao diện Sáng / Tối (Light & Dark Mode)',
                          subtitle: isDark
                              ? 'Đang bật chế độ Tối (Dark Mode)'
                              : 'Đang bật chế độ Sáng (Light Mode)',
                          trailing: Switch(
                            value: isDark,
                            activeTrackColor: AppTheme.primary,
                            onChanged: (_) => AppTheme.toggleTheme(),
                          ),
                          onTap: () => AppTheme.toggleTheme(),
                        ),
                        Divider(height: 14, color: AppTheme.border(context)),
                        _buildActionRow(
                          context: context,
                          icon: Icons.lock_reset_rounded,
                          iconColor: AppTheme.emerald,
                          title: 'Đổi mật khẩu bảo mật',
                          subtitle: 'Cập nhật mật khẩu đăng nhập cá nhân',
                          onTap: () =>
                              ModernAnimatedDialogs.showChangePasswordDialog(
                                  context),
                        ),
                        Divider(height: 14, color: AppTheme.border(context)),
                        _buildActionRow(
                          context: context,
                          icon: Icons.dns_outlined,
                          iconColor: AppTheme.purple,
                          title: 'Cấu hình kết nối Máy chủ API',
                          subtitle: 'Kiểm tra hoặc đổi địa chỉ IP LAN WebAPI',
                          onTap: () =>
                              ModernAnimatedDialogs.showServerConfigDialog(
                                  context),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 6. Logout Button
                StaggeredFadeSlide(
                  index: 6,
                  child: BounceTap(
                    onTap: _handleLogout,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.rose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.rose.withValues(alpha: 0.4),
                          width: 1.4,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: AppTheme.rose, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'ĐĂNG XUẤT TÀI KHOẢN',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.rose,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    bool allowCopy = false,
    String? copyText,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : 'Chưa cập nhật',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
        if (allowCopy)
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              size: 16,
              color: AppTheme.textSecondary(context),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: copyText ?? value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép mã nhân viên vào bộ nhớ tạm'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary(context),
                ),
          ],
        ),
      ),
    );
  }
}
