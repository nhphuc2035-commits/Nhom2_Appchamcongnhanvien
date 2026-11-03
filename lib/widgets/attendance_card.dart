import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../theme/app_theme.dart';
import 'modern_animated_dialogs.dart';
import 'staggered_animations.dart';

class AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;
  final VoidCallback? onTap;

  const AttendanceCard({
    super.key,
    required this.record,
    this.onTap,
  });

  String _dayName(int weekday) {
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

  String _formatOtBadge(double ot) {
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
    final isDark = AppTheme.isDark(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    final dateStr = dateFormat.format(record.attendanceDate);
    final dayLabel = _dayName(record.attendanceDate.weekday);
    final checkInStr = record.checkInTime != null
        ? timeFormat.format(record.checkInTime!)
        : '--:--';
    final checkOutStr = record.checkOutTime != null
        ? timeFormat.format(record.checkOutTime!)
        : '--:--';

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow(context),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date & Badges (FittedBox, Zero Ellipsis)
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        record.isManualEntry
                            ? Icons.edit_calendar_rounded
                            : Icons.event_available_rounded,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$dayLabel, $dateStr',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (record.overtimeHours > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: AppTheme.amber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _formatOtBadge(record.overtimeHours),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.amber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (record.isManualEntry
                              ? AppTheme.amber
                              : AppTheme.emerald)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: (record.isManualEntry
                                ? AppTheme.amber
                                : AppTheme.emerald)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      record.isManualEntry ? 'Chấm bù' : 'Chính chủ',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: record.isManualEntry
                            ? AppTheme.amber
                            : AppTheme.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Shift Name & Selfie Action Chip
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 15, color: AppTheme.primary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          record.shiftName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (record.proofImagePath != null) ...[
                const SizedBox(width: 8),
                BounceTap(
                  onTap: () => ModernAnimatedDialogs.showSelfieProofDialog(
                    context: context,
                    imageUrl: record.proofImagePath,
                    employeeName: record.employeeName,
                    timeString: checkInStr,
                    shiftName: record.shiftName,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded,
                            size: 14, color: AppTheme.primary),
                        SizedBox(width: 5),
                        Text(
                          'Ảnh selfie',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTimeBox(
                  context: context,
                  title: 'Giờ vào',
                  time: checkInStr,
                  icon: Icons.login_rounded,
                  color: AppTheme.emerald,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimeBox(
                  context: context,
                  title: 'Giờ về',
                  time: checkOutStr,
                  icon: Icons.logout_rounded,
                  color: record.checkOutTime != null
                      ? AppTheme.primary
                      : AppTheme.amber,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimeBox(
                  context: context,
                  title: 'Tổng giờ',
                  time: '${record.totalWorkingHours.toStringAsFixed(2)}h',
                  icon: Icons.timer_outlined,
                  color: AppTheme.purple,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (record.remarks != null && record.remarks!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.notes_rounded,
                  size: 15,
                  color: AppTheme.textSecondary(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _cleanRemark(record.remarks!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return BounceTap(onTap: onTap, child: cardContent);
    }
    return cardContent;
  }

  String _cleanRemark(String text) {
    if (text.contains('Chá') ||
        text.contains('cA\'ng') ||
        text.contains('Quá^2n') ||
        text.contains('thá>§') ||
        text.contains('bá>Ýi')) {
      return 'Chấm công thủ công bởi Quản lý';
    }
    return text;
  }

  Widget _buildTimeBox({
    required BuildContext context,
    required String title,
    required String time,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.elevated(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
