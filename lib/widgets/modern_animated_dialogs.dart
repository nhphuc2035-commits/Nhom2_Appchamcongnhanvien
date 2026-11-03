import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/config_url.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ModernAnimatedDialogs {
  static Future<void> showSuccessBiometric({
    required BuildContext context,
    required String title,
    required String employeeName,
    required String timeString,
    String statusText = 'Đã Liên Kết & Đồng Bộ Chính Chủ',
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SuccessBiometricDialog',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curvedAnim =
            CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.78, end: 1.0).animate(curvedAnim),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        final surface = AppTheme.surface(ctx);
        final textPrimary = AppTheme.textPrimary(ctx);
        final textSecondary = AppTheme.textSecondary(ctx);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 26),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.border(ctx)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emerald.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppTheme.emerald, AppTheme.emeraldDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.fingerprint_rounded,
                            color: Colors.white, size: 44),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Khóa bảo mật sinh trắc học đã đồng bộ với hồ sơ nhân viên',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.elevated(ctx),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border(ctx)),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            ctx,
                            'Nhân viên:',
                            employeeName,
                            Icons.person_outline_rounded,
                          ),
                          Divider(height: 16, color: AppTheme.border(ctx)),
                          _buildInfoRow(
                            ctx,
                            'Thời gian:',
                            timeString,
                            Icons.access_time_rounded,
                          ),
                          Divider(height: 16, color: AppTheme.border(ctx)),
                          _buildInfoRow(
                            ctx,
                            'Trạng thái:',
                            statusText,
                            Icons.verified_user_rounded,
                            valueColor: AppTheme.emerald,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Thiết bị đã khóa chính chủ. Khi vào ca làm, vui lòng ra Trang Chủ để bấm Check-in.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary(ctx),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Xác Nhận & Đóng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> showSuccessAttendance({
    required BuildContext context,
    required String title,
    required String employeeName,
    required String timeString,
    required bool isCheckIn,
    String? remarks,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SuccessDialog',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curvedAnim =
            CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.78, end: 1.0).animate(curvedAnim),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        final surface = AppTheme.surface(ctx);
        final textPrimary = AppTheme.textPrimary(ctx);
        final textSecondary = AppTheme.textSecondary(ctx);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 26),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.border(ctx)),
                boxShadow: [
                  BoxShadow(
                    color: (isCheckIn ? AppTheme.emerald : AppTheme.primary)
                        .withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isCheckIn
                              ? [AppTheme.emerald, AppTheme.emeraldDark]
                              : [AppTheme.primary, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isCheckIn
                                    ? AppTheme.emerald
                                    : AppTheme.primary)
                                .withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.check_rounded,
                            color: Colors.white, size: 44),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Xác thực vân tay phần cứng chính chủ hợp lệ',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.elevated(ctx),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border(ctx)),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            ctx,
                            'Nhân viên:',
                            employeeName,
                            Icons.person_outline_rounded,
                          ),
                          Divider(height: 16, color: AppTheme.border(ctx)),
                          _buildInfoRow(
                            ctx,
                            'Thời gian:',
                            timeString,
                            Icons.access_time_rounded,
                          ),
                          Divider(height: 16, color: AppTheme.border(ctx)),
                          _buildInfoRow(
                            ctx,
                            'Trạng thái:',
                            isCheckIn
                                ? 'Đã Vào Ca Thành Công'
                                : 'Đã Tan Ca Thành Công',
                            Icons.verified_rounded,
                            valueColor: isCheckIn
                                ? AppTheme.emerald
                                : AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Xác Nhận & Đóng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static BuildContext? _activeSecurityDialogContext;

  static void dismissActiveSecurityDialog() {
    if (_activeSecurityDialogContext != null) {
      try {
        Navigator.of(_activeSecurityDialogContext!, rootNavigator: true).pop();
      } catch (_) {}
      _activeSecurityDialogContext = null;
    }
  }

  static Future<void> showSecurityWarning({
    required BuildContext context,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    // Tự động đóng popup cảnh báo cũ nếu đang mở để tránh bị chồng chéo ("nùi nùi")
    dismissActiveSecurityDialog();

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'SecurityWarningDialog',
        barrierColor: Colors.black.withValues(alpha: 0.6),
        transitionDuration: const Duration(milliseconds: 340),
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curvedAnim =
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnim),
            child: FadeTransition(opacity: anim1, child: child),
          );
        },
        pageBuilder: (ctx, anim1, anim2) {
          _activeSecurityDialogContext = ctx;
          return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 26),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface(ctx),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.border(ctx)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.rose.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.rose.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.rose.withValues(alpha: 0.35),
                            width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(Icons.shield_outlined,
                            color: AppTheme.rose, size: 38),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary(ctx),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.elevated(ctx),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border(ctx)),
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AppTheme.textPrimary(ctx),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (actionLabel != null && onAction != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onAction();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Đóng',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(ctx),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.rose,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Đã Hiểu & Đóng',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    } finally {
      _activeSecurityDialogContext = null;
    }
  }

  static BuildContext? _activeNoInternetDialogContext;

  static void dismissActiveNoInternetDialog() {
    if (_activeNoInternetDialogContext != null) {
      try {
        Navigator.of(_activeNoInternetDialogContext!, rootNavigator: true).pop();
      } catch (_) {}
      _activeNoInternetDialogContext = null;
    }
  }

  /// Hộp thoại thông báo khi mất kết nối mạng hoặc không thể liên lạc tới máy chủ
  static Future<void> showNoInternetDialog({
    required BuildContext context,
    String? message,
  }) async {
    dismissActiveNoInternetDialog();

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'NoInternetDialog',
        barrierColor: Colors.black.withValues(alpha: 0.65),
        transitionDuration: const Duration(milliseconds: 320),
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curvedAnim =
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnim),
            child: FadeTransition(opacity: anim1, child: child),
          );
        },
        pageBuilder: (ctx, anim1, anim2) {
          _activeNoInternetDialogContext = ctx;
          final surface = AppTheme.surface(ctx);
          final textPrimary = AppTheme.textPrimary(ctx);
          final textSecondary = AppTheme.textSecondary(ctx);

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 26),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Mất Kết Nối Mạng!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message ??
                            'Không thể kết nối đến máy chủ. Vui lòng kết nối Wi-Fi hoặc dữ liệu di động (4G/5G) để tiếp tục sử dụng ứng dụng.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Đã Hiểu & Đóng',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _activeNoInternetDialogContext = null;
    }
  }

  static Future<bool> showConfirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = AppTheme.rose,
    IconData icon = Icons.logout_rounded,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ConfirmDialog',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 26),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface(ctx),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.border(ctx)),
                boxShadow: AppTheme.softShadow(ctx),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: confirmColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: confirmColor, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary(ctx),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textSecondary(ctx),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.border(ctx)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: Text(
                              'Hủy',
                              style: TextStyle(
                                color: AppTheme.textSecondary(ctx),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: confirmColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                            ),
                            child: Text(
                              confirmText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  /// Hộp thoại cấu hình địa chỉ máy chủ API (Dành cho test máy thật / LAN / Emulator)
  static Future<void> showServerConfigDialog(BuildContext context) async {
    final controller = TextEditingController(text: ConfigUrl.baseUrl);
    String statusMessage = '';
    bool isTesting = false;
    bool isOk = false;

    if (!context.mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ServerConfigDialog',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> testConnection() async {
              setModalState(() {
                isTesting = true;
                statusMessage = 'Đang kiểm tra kết nối tới máy chủ...';
              });

              final res = await ConfigUrl.testConnection(controller.text);
              setModalState(() {
                isTesting = false;
                isOk = res['success'] == true;
                statusMessage = res['message'] ?? '';
                if (isOk && res['url'] != null) {
                  controller.text = res['url'];
                }
              });
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(ctx),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppTheme.border(ctx)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.dns_rounded,
                                    color: AppTheme.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cấu hình Máy chủ API',
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary(ctx),
                                      ),
                                    ),
                                    Text(
                                      'Đang dùng: ${ConfigUrl.baseUrl}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(ctx),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Chọn nhanh máy chủ hoặc tự nhập URL:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary(ctx),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.cloud_done_rounded,
                                    size: 15, color: Color(0xFF38BDF8)),
                                label: const Text('Ngrok (Từ xa / 4G)',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                                side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
                                onPressed: () {
                                  setModalState(() {
                                    controller.text = ConfigUrl.defaultNgrok;
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.computer_rounded,
                                    size: 15, color: AppTheme.amber),
                                label: const Text('Localhost (5266)',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                backgroundColor: AppTheme.amber.withValues(alpha: 0.12),
                                side: BorderSide(color: AppTheme.amber.withValues(alpha: 0.35)),
                                onPressed: () {
                                  setModalState(() {
                                    controller.text = ConfigUrl.defaultLocalhost;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppTheme.textPrimary(ctx),
                            ),
                            decoration: InputDecoration(
                              hintText: 'VD: ${ConfigUrl.defaultNgrok}',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary(ctx),
                              ),
                              filled: true,
                              fillColor: AppTheme.elevated(ctx),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: AppTheme.border(ctx)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: AppTheme.border(ctx)),
                              ),
                            ),
                          ),
                          if (statusMessage.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isOk
                                        ? AppTheme.emerald
                                        : AppTheme.amber)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusMessage,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isOk ? AppTheme.emerald : AppTheme.amber,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: isTesting ? null : testConnection,
                                icon: isTesting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.wifi_find_rounded,
                                        size: 16),
                                label: const Text('Test kết nối',
                                    style: TextStyle(fontSize: 12.5)),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Đóng'),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (controller.text.trim().isEmpty) {
                                        await ConfigUrl.resetToDefault();
                                      } else {
                                        await ConfigUrl.setCustomBaseUrl(
                                            controller.text);
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Lưu'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Hộp thoại đổi mật khẩu cho nhân viên
  static Future<void> showChangePasswordDialog(BuildContext context) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ChangePasswordDialog',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(ctx),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppTheme.border(ctx)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đổi mật khẩu tài khoản',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary(ctx),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordField(
                              ctx, currentCtrl, 'Mật khẩu hiện tại'),
                          const SizedBox(height: 12),
                          _buildPasswordField(
                              ctx, newCtrl, 'Mật khẩu mới (tối thiểu 6 ký tự)'),
                          const SizedBox(height: 12),
                          _buildPasswordField(
                              ctx, confirmCtrl, 'Nhập lại mật khẩu mới'),
                          if (errorMsg != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              errorMsg!,
                              style: const TextStyle(
                                color: AppTheme.rose,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Hủy'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        if (currentCtrl.text.isEmpty ||
                                            newCtrl.text.length < 6) {
                                          setModalState(() {
                                            errorMsg =
                                                'Mật khẩu mới phải từ 6 ký tự trở lên.';
                                          });
                                          return;
                                        }
                                        if (newCtrl.text != confirmCtrl.text) {
                                          setModalState(() {
                                            errorMsg =
                                                'Xác nhận mật khẩu mới không khớp.';
                                          });
                                          return;
                                        }
                                        setModalState(() {
                                          isLoading = true;
                                          errorMsg = null;
                                        });
                                        final res =
                                            await AuthService.changePassword(
                                          currentPassword: currentCtrl.text,
                                          newPassword: newCtrl.text,
                                        );
                                        if (!ctx.mounted) return;
                                        if (res['success'] == true) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(res['message']),
                                              backgroundColor: AppTheme.emerald,
                                            ),
                                          );
                                        } else {
                                          final errorText = res['message'] ?? 'Đổi mật khẩu thất bại.';
                                          if (ApiClient.isNetworkError(errorText)) {
                                            Navigator.pop(ctx);
                                            ModernAnimatedDialogs.showNoInternetDialog(context: context);
                                            return;
                                          }
                                          setModalState(() {
                                            isLoading = false;
                                            errorMsg = errorText;
                                          });
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Cập nhật mật khẩu'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildPasswordField(
    BuildContext context,
    TextEditingController controller,
    String label,
  ) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: TextStyle(fontSize: 13.5, color: AppTheme.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(fontSize: 12.5, color: AppTheme.textSecondary(context)),
        filled: true,
        fillColor: AppTheme.elevated(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border(context)),
        ),
      ),
    );
  }

  static Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary(context)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: AppTheme.textSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Hộp thoại xem ảnh Selfie minh chứng điểm danh (có hỗ trợ phóng to InteractiveViewer)
  static Future<void> showSelfieProofDialog({
    required BuildContext context,
    required String? imageUrl,
    required String employeeName,
    required String timeString,
    String? shiftName,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) return Future.value();
    final fullUrl = ConfigUrl.formatImageUrl(imageUrl);
    if (fullUrl == null) return Future.value();

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SelfieProofDialog',
      barrierColor: Colors.black.withValues(alpha: 0.70),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curvedAnim =
            CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnim),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        final surface = AppTheme.surface(ctx);
        final textPrimary = AppTheme.textPrimary(ctx);
        final textSecondary = AppTheme.textSecondary(ctx);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.border(ctx)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.28),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: AppTheme.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ảnh Selfie Điểm Danh',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'Dùng 2 ngón tay chạm & kéo để phóng to',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: textSecondary, size: 22),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Image with InteractiveViewer zoom
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            color: Colors.black,
                            width: double.infinity,
                            child: InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 4.0,
                              child: Center(
                                child: Image.network(
                                  fullUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.broken_image_rounded,
                                            size: 42, color: Colors.white54),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Không thể tải ảnh selfie',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.8),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Metadata info card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppTheme.elevated(ctx),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border(ctx)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user_rounded,
                                    size: 15, color: AppTheme.emerald),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    employeeName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Thời gian vào ca: $timeString',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            if (shiftName != null && shiftName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Ca làm việc: $shiftName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
