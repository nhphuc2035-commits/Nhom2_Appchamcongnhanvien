import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class AnimatedAttendanceButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final VoidCallback? onDisabledTap;
  final bool isCheckIn;
  final bool isCompleted;
  final bool? isEnabled;

  const AnimatedAttendanceButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
    this.onDisabledTap,
    this.isCheckIn = true,
    this.isCompleted = false,
    this.isEnabled,
  });

  @override
  State<AnimatedAttendanceButton> createState() =>
      _AnimatedAttendanceButtonState();
}

class _AnimatedAttendanceButtonState extends State<AnimatedAttendanceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  bool get _effectiveEnabled => widget.isEnabled ?? (widget.onTap != null);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _glowAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_effectiveEnabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedAttendanceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_effectiveEnabled && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_effectiveEnabled && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = _effectiveEnabled;
    final bool isDark = AppTheme.isDark(context);

    final List<Color> disabledGradient = isDark
        ? [const Color(0xFF1E293B), const Color(0xFF334155)]
        : [const Color(0xFFCBD5E1), const Color(0xFF94A3B8)];

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            if (isEnabled) {
              HapticFeedback.mediumImpact();
              widget.onTap?.call();
            } else {
              HapticFeedback.lightImpact();
              widget.onDisabledTap?.call();
            }
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              constraints: const BoxConstraints(minHeight: 142),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isEnabled ? widget.gradientColors : disabledGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isEnabled
                      ? Colors.white.withValues(alpha: 0.28)
                      : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
                  width: 1.4,
                ),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: widget.gradientColors.first
                              .withValues(alpha: 0.38),
                          blurRadius: _glowAnimation.value + 2,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: isEnabled ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: isEnabled ? 0.50 : 0.20),
                        width: 1.8,
                      ),
                      boxShadow: isEnabled
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.25),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      widget.isCompleted
                          ? Icons.verified_rounded
                          : widget.icon,
                      size: 30,
                      color: isEnabled
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                        color: isEnabled
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.white),
                        letterSpacing: 0.8,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.black
                            .withValues(alpha: isEnabled ? 0.28 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(
                              alpha: isEnabled ? 0.22 : 0.10),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isEnabled && !widget.isCompleted) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ] else if (widget.isCompleted) ...[
                            const Icon(Icons.check_rounded,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white
                                  .withValues(alpha: isEnabled ? 1.0 : 0.8),
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
        );
      },
    );
  }
}
