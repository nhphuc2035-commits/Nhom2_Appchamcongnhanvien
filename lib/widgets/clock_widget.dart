import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class ClockWidget extends StatefulWidget {
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double completedHours;
  final String shiftName;
  final LocationCheckResult? locationStatus;
  final VoidCallback? onTapLocation;
  final String? proofImagePath;
  final VoidCallback? onTapProofImage;

  const ClockWidget({
    super.key,
    this.checkInTime,
    this.checkOutTime,
    this.completedHours = 0.0,
    this.shiftName = 'Ca Hành Chính (08:00 - 17:00)',
    this.locationStatus,
    this.onTapLocation,
    this.proofImagePath,
    this.onTapProofImage,
  });

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late DateTime _currentTime;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _getDayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  int _getMaxGateMinutes(String shiftName) {
    if (shiftName.contains('Sáng')) return 12 * 60 + 15; // Ca sáng khóa lúc 12:15
    if (shiftName.contains('Chiều') || shiftName.contains('Tối')) {
      return 22 * 60 + 30; // Ca chiều/tối khóa lúc 22:30
    }
    return 18 * 60; // Ca hành chính khóa lúc 18:00
  }

  double _calculateLiveHours() {
    if (widget.checkInTime != null && widget.checkOutTime == null) {
      final nowTime = _currentTime;
      final today = widget.checkInTime!;

      // Xác định giờ bắt đầu và kết thúc chuẩn của ca làm việc
      final int startHour = widget.shiftName.contains('Sáng')
          ? 6
          : (widget.shiftName.contains('Chiều')
              ? 14
              : (widget.shiftName.contains('Tối') ? 18 : 8));

      final int endHour = widget.shiftName.contains('Sáng')
          ? 12
          : (widget.shiftName.contains('Chiều') ||
                  widget.shiftName.contains('Tối')
              ? 22
              : 17);

      final shiftStart =
          DateTime(today.year, today.month, today.day, startHour, 0);
      final shiftEnd =
          DateTime(today.year, today.month, today.day, endHour, 0);

      // QUY TẮC: Vào sớm trước giờ ca -> tính công bắt đầu từ đúng giờ ca chuẩn (0h OT vào sớm)
      final effectiveStart = widget.checkInTime!.isBefore(shiftStart)
          ? shiftStart
          : widget.checkInTime!;

      // Nếu hiện tại chưa đến giờ bắt đầu ca (ví dụ 07:30): chưa phát sinh giờ làm
      if (nowTime.isBefore(effectiveStart)) {
        return 0.0;
      }

      // Giờ kết thúc: Chốt trần tại giờ kết thúc ca chuẩn đối với ca tiêu chuẩn
      DateTime effectiveEnd = nowTime;
      if (!widget.shiftName.contains('Tối') && nowTime.isAfter(shiftEnd)) {
        effectiveEnd = shiftEnd;
      } else if (widget.shiftName.contains('Tối') && nowTime.isAfter(shiftEnd)) {
        effectiveEnd = shiftEnd;
      }

      final diffSeconds =
          effectiveEnd.difference(effectiveStart).inSeconds;
      if (diffSeconds > 0) {
        if (widget.shiftName.contains('Hành Chính')) {
          final lunchStart =
              DateTime(today.year, today.month, today.day, 12, 0);
          final lunchEnd =
              DateTime(today.year, today.month, today.day, 13, 0);
          double lunchDeduction = 0.0;
          if (effectiveEnd.isAfter(lunchStart)) {
            final overlapStart = effectiveStart.isAfter(lunchStart)
                ? effectiveStart
                : lunchStart;
            final overlapEnd =
                effectiveEnd.isBefore(lunchEnd) ? effectiveEnd : lunchEnd;
            if (overlapEnd.isAfter(overlapStart)) {
              lunchDeduction =
                  overlapEnd.difference(overlapStart).inMinutes / 60.0;
            }
          }
          final hours = (diffSeconds / 3600.0) - lunchDeduction;
          return hours > 0 ? hours : 0.0;
        }
        return diffSeconds / 3600.0;
      }
    }
    return widget.completedHours;
  }

  String _formatOtText(double ot) {
    if (ot == ot.roundToDouble()) {
      return '+${ot.toInt()}h Tăng ca';
    }
    final s1 = ot.toStringAsFixed(1);
    if (double.parse(s1) == ot) {
      return '+${s1}h Tăng ca';
    }
    return '+${ot.toStringAsFixed(2)}h Tăng ca';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppTheme.isDark(context);
    final timeStr = DateFormat('HH:mm:ss').format(_currentTime);
    final dateStr = DateFormat('dd/MM/yyyy').format(_currentTime);
    final dayOfWeek = _getDayOfWeek(_currentTime.weekday);
    final bool isSunday = _currentTime.weekday == DateTime.sunday;

    final bool hasCheckedIn = widget.checkInTime != null;
    final bool hasCheckedOut = widget.checkOutTime != null;
    final bool isWorkingNow = hasCheckedIn && !hasCheckedOut;
    final bool isCompletedToday = hasCheckedIn && hasCheckedOut;

    final timeFmt = DateFormat('HH:mm');
    final checkInStr = hasCheckedIn ? timeFmt.format(widget.checkInTime!) : '--:--';
    final checkOutStr = hasCheckedOut ? timeFmt.format(widget.checkOutTime!) : '--:--';

    final bool isEveningShift = widget.shiftName.contains('18:00');
    final double targetShiftHours = isEveningShift ? 4.0 : 8.0;

    final int currentMins = _currentTime.hour * 60 + _currentTime.minute;
    final int maxGateMins = _getMaxGateMinutes(widget.shiftName);
    final bool isShiftOverdue = isWorkingNow && (currentMins > maxGateMins);

    final double liveHours = _calculateLiveHours();
    final double progress = (liveHours / targetShiftHours).clamp(0.0, 1.0);
    final double overtime = (liveHours > targetShiftHours && !isShiftOverdue)
        ? liveHours - targetShiftHours
        : 0.0;

    // GPS Status pill styling
    final loc = widget.locationStatus;
    final bool isGpsOff = loc?.statusType == LocationStatusType.serviceDisabled;
    final bool isLocInside = loc?.isInside == true;
    final Color gpsColor = isGpsOff
        ? (isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48))
        : (isLocInside
            ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
            : (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)));
    final String gpsLabel = isGpsOff
        ? 'Bật GPS'
        : (isLocInside ? 'Tại công ty' : 'Ngoài phạm vi');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? null : Colors.white,
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Colors.white, Color(0xFFF8FAFC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                : const Color(0xFF64748B).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top row: Date + GPS Geofence Pill (Zero Overflow Guaranteed)
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSunday ? Icons.weekend_rounded : Icons.calendar_today_rounded,
                      color: isSunday
                          ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B))
                          : (isDark ? Colors.white70 : AppTheme.primary),
                      size: 15,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '$dayOfWeek, $dateStr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isSunday
                              ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706))
                              : (isDark ? Colors.white : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTapLocation,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? gpsColor.withValues(alpha: 0.2)
                          : gpsColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? gpsColor.withValues(alpha: 0.5)
                            : gpsColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isGpsOff
                              ? Icons.location_disabled_rounded
                              : (isLocInside
                                  ? Icons.location_on_rounded
                                  : Icons.location_off_rounded),
                          color: gpsColor,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          gpsLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: gpsColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Real-time Live Digital Clock Display
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: 2.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: isDark
                      ? const [
                          Shadow(
                            color: Color(0x6638BDF8),
                            blurRadius: 16,
                          ),
                        ]
                      : const [
                          Shadow(
                            color: Color(0x142563EB),
                            blurRadius: 10,
                          ),
                        ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Shift & Work Status Pill (Fully Constrained - Zero Overflow)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isShiftOverdue
                    ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.18 : 0.10)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isShiftOverdue
                      ? const Color(0xFFF87171).withValues(alpha: isDark ? 0.6 : 0.4)
                      : (isWorkingNow
                              ? const Color(0xFF10B981)
                              : (isCompletedToday
                                  ? const Color(0xFF0EA5E9)
                                  : const Color(0xFFF59E0B)))
                          .withValues(alpha: isDark ? 0.45 : 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final dotColor = isShiftOverdue
                          ? const Color(0xFFEF4444)
                          : (isWorkingNow
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981))
                              : (isCompletedToday
                                  ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                  : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))));
                      return Container(
                        width: 8.5,
                        height: 8.5,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: dotColor.withValues(
                                  alpha: 0.4 + (_pulseController.value * 0.5)),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      isShiftOverdue
                          ? '⚠️ Quá giờ tan ca • Đã khóa ca'
                          : (isWorkingNow
                              ? 'Đang làm việc'
                              : (isCompletedToday
                                  ? 'Đã hoàn tất ca hôm nay'
                                  : 'Chờ vào ca')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isShiftOverdue
                            ? (isDark ? const Color(0xFFFDE047) : const Color(0xFFDC2626))
                            : (isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isSunday) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                  size: 15,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Chủ Nhật nghỉ tuần • Điểm danh tính lương Tăng ca x2.0',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 18),

          // 4. Two Big Spacious Stat Panels: GIỜ VÀO & GIỜ RA
          Row(
            children: [
              // Panel 1: GIỜ VÀO CA
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: hasCheckedIn
                          ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.45)
                          : (isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0)),
                      width: 1.1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 15,
                            color: hasCheckedIn
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                : (isDark ? Colors.white60 : const Color(0xFF94A3B8)),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'GIỜ VÀO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          checkInStr,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: hasCheckedIn
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasCheckedIn ? 'Đã điểm danh' : 'Chưa vào ca',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: hasCheckedIn
                              ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857))
                              : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Panel 2: GIỜ TAN CA
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: hasCheckedOut
                          ? const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.35 : 0.45)
                          : (isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0)),
                      width: 1.1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 15,
                            color: hasCheckedOut
                                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                : (isDark ? Colors.white60 : const Color(0xFF94A3B8)),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'GIỜ TAN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          checkOutStr,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: hasCheckedOut
                                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasCheckedOut ? 'Đã hoàn tất' : 'Chờ tan ca',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: hasCheckedOut
                              ? (isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1))
                              : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 5. Shift Duration Progress Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        Icons.timelapse_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF38BDF8) : AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isShiftOverdue
                            ? 'Đã chốt công: ${targetShiftHours.toStringAsFixed(1)}h • Ca đã tự khóa'
                            : 'Tiến độ làm việc: ${liveHours.toStringAsFixed(1)}h / ${targetShiftHours.toStringAsFixed(0)}h',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isShiftOverdue
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white : const Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isShiftOverdue
                      ? const Color(0xFFEF4444)
                      : (overtime > 0
                          ? const Color(0xFFF59E0B)
                          : (isDark
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : const Color(0xFFDCFCE7))),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isShiftOverdue
                        ? const Color(0xFFEF4444)
                        : (overtime > 0
                            ? const Color(0xFFF59E0B)
                            : (isDark
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : const Color(0xFF86EFAC))),
                  ),
                ),
                child: Text(
                  isShiftOverdue
                      ? 'Đã khóa ca'
                      : (overtime > 0
                          ? _formatOtText(overtime)
                          : '${(progress * 100).clamp(0, 100).toInt()}%'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isShiftOverdue || overtime > 0
                        ? Colors.white
                        : (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // 6. Bold High-Tech Progress Bar (14px Height)
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFCBD5E1),
                width: 1,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                final double fillWidth =
                    (totalWidth * progress).clamp(0.0, totalWidth);
                return Stack(
                  children: [
                    if (fillWidth > 0)
                      Container(
                        width: fillWidth,
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isShiftOverdue
                                ? const [Color(0xFFDC2626), Color(0xFFEF4444)]
                                : (overtime > 0
                                    ? const [
                                        Color(0xFFD97706),
                                        Color(0xFFF59E0B)
                                      ]
                                    : const [
                                        Color(0xFF059669),
                                        Color(0xFF10B981),
                                        Color(0xFF34D399)
                                      ]),
                          ),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: isShiftOverdue
                                  ? const Color(0xFFEF4444)
                                      .withValues(alpha: 0.5)
                                  : (overtime > 0
                                      ? const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.5)
                                      : const Color(0xFF10B981)
                                          .withValues(alpha: 0.5)),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // 7. Today's Selfie Access Pill (Xem ảnh selfie vào ca hôm nay)
          if (widget.proofImagePath != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: widget.onTapProofImage,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: isDark ? const Color(0xFF67E8F9) : AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Xem ảnh selfie lúc vào ca hôm nay',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
