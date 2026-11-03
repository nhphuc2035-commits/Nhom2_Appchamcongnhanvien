import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hiệu ứng xuất hiện tuần tự (Fade + Slide Up) cho mọi Card / Phần tử giao diện
class StaggeredFadeSlide extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  const StaggeredFadeSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds + (index.clamp(0, 12) * 55);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: totalMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * offsetY),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}

/// Hiệu ứng nhảy số mượt mà cho Tiền lương, Giờ làm, Ngày công
class AnimatedNumberText extends StatelessWidget {
  final double value;
  final String Function(double val) formatter;
  final TextStyle? style;
  final Duration duration;

  const AnimatedNumberText({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutQuart,
      builder: (context, animatedValue, _) {
        return Text(
          formatter(animatedValue),
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// Bọc bất kỳ Widget nào để có hiệu ứng nhấn co giãn (Scale Bounce) + Haptic Feedback
class BounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const BounceTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
  });

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
