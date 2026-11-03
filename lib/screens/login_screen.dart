import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/network_service.dart';
import '../widgets/modern_animated_dialogs.dart';
import '../widgets/staggered_animations.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
      return;
    }

    final lastUser = await AuthService.getLastUsername();
    final lastEmail = await AuthService.getLastEmail();

    // Mặc định ưu tiên hiển thị Email thay vì Tên đăng nhập
    String defaultInput = '';
    if (lastEmail != null && lastEmail.trim().isNotEmpty && lastEmail.contains('@')) {
      defaultInput = lastEmail.trim();
    } else if (lastUser != null && lastUser.contains('@')) {
      defaultInput = lastUser.trim();
    } else if (lastUser != null && lastUser.isNotEmpty) {
      if (lastUser.toLowerCase() == 'nguyen.van.phuc') {
        defaultInput = 'nhphuc2035@gmail.com';
      } else {
        defaultInput = '$lastUser@novacorp.vn';
      }
    } else {
      defaultInput = 'nhphuc2035@gmail.com';
    }

    if (mounted) {
      setState(() {
        if (_usernameController.text.isEmpty) {
          _usernameController.text = defaultInput;
        }
      });
    }
  }

  Future<void> _handleQuickBiometricLogin() async {
    final prefs = await SharedPreferences.getInstance();
    var username = _usernameController.text.trim();

    // Tự động lấy tài khoản đăng nhập gần nhất nếu ô nhập còn trống
    if (username.isEmpty) {
      final lastEmail = prefs.getString('last_email');
      final lastUser = prefs.getString('last_username');
      final fallback = (lastEmail != null && lastEmail.isNotEmpty) ? lastEmail : lastUser;
      if (fallback != null && fallback.isNotEmpty) {
        username = fallback;
        _usernameController.text = fallback;
      }
    }

    if (!mounted) return;

    if (username.isEmpty) {
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Chưa Chọn Tài Khoản',
        message:
            'Vui lòng nhập Email hoặc Tên đăng nhập để đăng nhập bằng vân tay.',
      );
      return;
    }

    // Tìm mật khẩu đã lưu theo username, email hoặc lastUser
    var savedPwd = prefs.getString('saved_pwd_${username.toLowerCase()}');
    if (savedPwd == null || savedPwd.isEmpty) {
      final lastEmail = prefs.getString('last_email')?.toLowerCase();
      if (lastEmail != null && lastEmail.isNotEmpty) {
        savedPwd = prefs.getString('saved_pwd_$lastEmail');
      }
    }
    if (savedPwd == null || savedPwd.isEmpty) {
      final lastUser = prefs.getString('last_username')?.toLowerCase();
      if (lastUser != null && lastUser.isNotEmpty) {
        savedPwd = prefs.getString('saved_pwd_$lastUser');
      }
    }

    if (savedPwd == null || savedPwd.isEmpty) {
      if (!mounted) return;
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Chưa Lưu Khóa Đăng Nhập',
        message:
            'Tài khoản "$username" chưa từng đăng nhập trên thiết bị này.\n\nVui lòng đăng nhập bằng mật khẩu 1 lần đầu tiên để kích hoạt tính năng đăng nhập nhanh bằng vân tay.',
      );
      return;
    }

    // Kiểm tra phần cứng vân tay của thiết bị
    final hwState = await BiometricService.getBiometricHardwareState();
    if (hwState == 'NO_HARDWARE') {
      if (!mounted) return;
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Không Có Cảm Biến',
        message: 'Thiết bị này không có phần cứng cảm biến vân tay.',
      );
      return;
    }
    if (hwState == 'NONE_ENROLLED') {
      if (!mounted) return;
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Chưa Cài Đặt Vân Tay',
        message: 'Điện thoại chưa cài đặt vân tay nào trong máy. Vui lòng vào Cài đặt máy để đăng ký vân tay.',
      );
      return;
    }

    // Kích hoạt cửa sổ quét vân tay chuẩn OS Android
    final localAuth = LocalAuthentication();
    bool authenticated = false;
    try {
      authenticated = await localAuth.authenticate(
        localizedReason: 'Chạm cảm biến vân tay để đăng nhập nhanh tài khoản $username',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric login error: $e');
    }

    if (authenticated) {
      _passwordController.text = savedPwd;
      await _handleLogin();
    }
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ModernAnimatedDialogs.showSecurityWarning(
        context: context,
        title: 'Thiếu Thông Tin',
        message: 'Vui lòng nhập đầy đủ Email/Tên đăng nhập và Mật khẩu để đăng nhập.',
      );
      return;
    }

    final isOnline = await NetworkService.checkConnectivity();
    if (!isOnline) {
      if (mounted) {
        ModernAnimatedDialogs.showNoInternetDialog(context: context);
      }
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.login(username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Lưu lại mật khẩu cho cả tên đăng nhập gõ vào và canonical username/email từ server
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_pwd_${username.toLowerCase()}', password);
      if (username.contains('@')) {
        await prefs.setString('last_email', username);
      }
      final lastUser = prefs.getString('last_username')?.toLowerCase();
      if (lastUser != null && lastUser.isNotEmpty) {
        await prefs.setString('saved_pwd_$lastUser', password);
      }
      final userEmail = prefs.getString('user_email')?.toLowerCase();
      if (userEmail != null && userEmail.isNotEmpty) {
        await prefs.setString('saved_pwd_$userEmail', password);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: animation,
            child: const MainNavigationScreen(),
          ),
        ),
      );
    } else {
      final msg = result['message'] ??
          'Đăng nhập thất bại. Vui lòng kiểm tra lại tài khoản hoặc mật khẩu.';
      if (ApiClient.isNetworkError(msg)) {
        ModernAnimatedDialogs.showNoInternetDialog(context: context);
      } else {
        ModernAnimatedDialogs.showSecurityWarning(
          context: context,
          title: 'Thông Báo Đăng Nhập',
          message: msg,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E40AF).withValues(alpha: 0.28),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0284C7).withValues(alpha: 0.22),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Mini Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_android_rounded,
                                color: Color(0xFF38BDF8), size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Cổng Nhân Viên',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BounceTap(
                        onTap: () =>
                            ModernAnimatedDialogs.showServerConfigDialog(
                                context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.dns_outlined,
                                  color: Color(0xFF38BDF8), size: 15),
                              SizedBox(width: 5),
                              Text(
                                'Cấu hình máy chủ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Animated Pulsing Biometric Emblem
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  return Container(
                                    width: 86,
                                    height: 86,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF0F2B48),
                                          Color(0xFF1E3A5F)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFF38BDF8)
                                            .withValues(alpha: 0.55),
                                        width: 1.8,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF38BDF8)
                                              .withValues(
                                                  alpha: 0.2 +
                                                      (_pulseController.value *
                                                          0.25)),
                                          blurRadius:
                                              20 + (_pulseController.value * 12),
                                          spreadRadius: 2,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.apartment_rounded,
                                        size: 46,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 18),

                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'CÔNG TY CỔ PHẦN NOVA',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Chấm Công & Quản Trị Nhân Sự',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 26),

                              // Glassmorphism Login Card
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 22, vertical: 24),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF131D31)
                                          .withValues(alpha: 0.88),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.12),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Đăng Nhập Nhân Viên',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Sử dụng tài khoản nhân sự được cấp để chấm công',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                        const SizedBox(height: 20),

                                        _buildInputField(
                                          controller: _usernameController,
                                          label: 'Email hoặc Tên đăng nhập',
                                          hint: 'Ví dụ: nhphuc2035@gmail.com hoặc nguyen.van.an',
                                          icon: Icons.alternate_email_rounded,
                                        ),
                                        const SizedBox(height: 16),

                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: _buildInputField(
                                                controller: _passwordController,
                                                label: 'Mật khẩu bảo mật',
                                                hint: '••••••••',
                                                icon: Icons.lock_outline_rounded,
                                                isPassword: true,
                                                obscureText: _obscurePassword,
                                                onTogglePassword: () {
                                                  setState(() => _obscurePassword =
                                                      !_obscurePassword);
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Tooltip(
                                              message: 'Đăng nhập bằng vân tay',
                                              child: BounceTap(
                                                onTap: _handleQuickBiometricLogin,
                                                child: Container(
                                                  width: 50,
                                                  height: 50,
                                                  margin: const EdgeInsets.only(bottom: 1),
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [
                                                        Color(0xFF0284C7),
                                                        Color(0xFF2563EB),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(
                                                      color: const Color(0xFF38BDF8)
                                                          .withValues(alpha: 0.55),
                                                      width: 1.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF0284C7)
                                                            .withValues(alpha: 0.45),
                                                        blurRadius: 12,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.fingerprint_rounded,
                                                      color: Colors.white,
                                                      size: 30,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),

                                        BounceTap(
                                          onTap:
                                              _isLoading ? null : _handleLogin,
                                          child: Container(
                                            width: double.infinity,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF0284C7),
                                                  Color(0xFF2563EB),
                                                  Color(0xFF1D4ED8),
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color:
                                                      const Color(0xFF2563EB)
                                                          .withValues(
                                                              alpha: 0.42),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: _isLoading
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2.2,
                                                      ),
                                                    )
                                                  : const Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          'VÀO HỆ THỐNG',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Colors.white,
                                                            letterSpacing: 1.1,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Icon(
                                                          Icons
                                                              .arrow_forward_rounded,
                                                          color: Colors.white,
                                                          size: 18,
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Hệ thống Chấm công & Quản trị Nhân sự NOVA CORP',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withValues(alpha: 0.48),
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1120),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? obscureText : false,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 13,
              ),
              prefixIcon:
                  Icon(icon, color: const Color(0xFF38BDF8), size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      onPressed: onTogglePassword,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
