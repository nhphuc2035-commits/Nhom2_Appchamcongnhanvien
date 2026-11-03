import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/config_url.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_card.dart';
import '../widgets/modern_animated_dialogs.dart';
import '../widgets/staggered_animations.dart';

class HistoryScreen extends StatefulWidget {
  final ScrollController? scrollController;

  const HistoryScreen({
    super.key,
    this.scrollController,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ScrollController? _internalScrollController;
  ScrollController get _activeScrollController =>
      widget.scrollController ??
      (_internalScrollController ??= ScrollController());

  final AttendanceService _attendanceService = AttendanceService();
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  String _filterType = 'Month'; // 'Week' | 'Month' | 'Quarter' | 'Year' | 'All'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _internalScrollController?.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    DateTime? fromDate;
    final now = DateTime.now();

    if (_filterType == 'Week') {
      fromDate = now.subtract(Duration(days: now.weekday - 1));
      fromDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
    } else if (_filterType == 'Month') {
      fromDate = DateTime(now.year, now.month, 1);
    } else if (_filterType == 'Quarter') {
      final int quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      fromDate = DateTime(now.year, quarterStartMonth, 1);
    } else if (_filterType == 'Year') {
      fromDate = DateTime(now.year, 1, 1);
    }

    final data = await _attendanceService.getMyHistory(fromDate: fromDate);

    if (mounted) {
      setState(() {
        _records = data;
        _isLoading = false;
      });
    }
  }

  void _showRecordDetailSheet(AttendanceRecord record) {
    final dateStr = DateFormat('dd/MM/yyyy').format(record.attendanceDate);
    final timeFmt = DateFormat('HH:mm:ss');
    final inStr = record.checkInTime != null
        ? timeFmt.format(record.checkInTime!)
        : 'Chưa ghi nhận';
    final outStr = record.checkOutTime != null
        ? timeFmt.format(record.checkOutTime!)
        : 'Chưa tan ca';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return Container(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.88,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface(ctx),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.border(ctx)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 10),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          AppTheme.textSecondary(ctx).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Date & Auth Badge (Zero Overflow Guarantee)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chi tiết ngày công',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary(ctx),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.textPrimary(ctx),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (record.isHybrid)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.fingerprint_rounded,
                                    size: 14,
                                    color: AppTheme.emerald,
                                  ),
                                  const SizedBox(width: 3),
                                  const Text(
                                    'Vào: Vân tay',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.emerald,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: Text(
                                      '|',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: AppTheme.textSecondary(ctx).withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit_note_rounded,
                                    size: 15,
                                    color: AppTheme.amber,
                                  ),
                                  const SizedBox(width: 3),
                                  const Text(
                                    'Ra: Chấm bù',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.amber,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (record.isManualEntry
                                        ? AppTheme.amber
                                        : AppTheme.emerald)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (record.isManualEntry
                                          ? AppTheme.amber
                                          : AppTheme.emerald)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    record.isManualEntry
                                        ? Icons.edit_note_rounded
                                        : Icons.fingerprint_rounded,
                                    size: 15,
                                    color: record.isManualEntry
                                        ? AppTheme.amber
                                        : AppTheme.emerald,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    record.isManualEntry
                                        ? 'Quản lý chấm bù'
                                        : 'Vân tay chính chủ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: record.isManualEntry
                                          ? AppTheme.amber
                                          : AppTheme.emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // SELFIE PROOF SECTION (Hiển thị ảnh selfie khoảnh khắc check-in)
                      if (record.proofImagePath != null) ...[
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.elevated(ctx),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.border(ctx)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 12, 14, 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.14),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 15,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Ảnh selfie xác thực vào ca',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary(ctx),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Chạm để phóng to',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    ModernAnimatedDialogs.showSelfieProofDialog(
                                  context: ctx,
                                  imageUrl: record.proofImagePath,
                                  employeeName: record.employeeName,
                                  timeString: inStr,
                                  shiftName: record.shiftName,
                                ),
                                child: Container(
                                  margin:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  height: 190,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Colors.black12,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          ConfigUrl.formatImageUrl(
                                              record.proofImagePath)!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image_rounded,
                                                  size: 36,
                                                  color: AppTheme.textSecondary(
                                                      ctx),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Không thể tải ảnh selfie',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppTheme.textSecondary(
                                                            ctx),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.65),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.zoom_in_rounded,
                                                    color: Colors.white,
                                                    size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Phóng to',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary(ctx)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border(ctx)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.no_photography_rounded,
                                size: 18,
                                color: AppTheme.textSecondary(ctx),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  record.isManualEntry
                                      ? 'Bản ghi Quản lý chấm bù (Không có ảnh selfie)'
                                      : 'Bản ghi không đính kèm ảnh selfie',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary(ctx),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Metrics Details Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.elevated(ctx),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.border(ctx)),
                        ),
                        child: Column(
                          children: [
                            _buildDetailLine(
                              ctx,
                              'Ca làm việc:',
                              record.shiftName,
                              AppTheme.primary,
                            ),
                            Divider(height: 18, color: AppTheme.border(ctx)),
                            _buildDetailLine(
                              ctx,
                              'Giờ vào ca (Check-in):',
                              inStr,
                              AppTheme.emerald,
                            ),
                            Divider(height: 18, color: AppTheme.border(ctx)),
                            _buildDetailLine(
                              ctx,
                              'Giờ tan ca (Check-out):',
                              outStr,
                              record.checkOutTime != null
                                  ? AppTheme.primary
                                  : AppTheme.amber,
                            ),
                            Divider(height: 18, color: AppTheme.border(ctx)),
                            _buildDetailLine(
                              ctx,
                              'Giờ làm tiêu chuẩn:',
                              '${record.regularHours.toStringAsFixed(2)} giờ',
                              AppTheme.textPrimary(ctx),
                            ),
                            Divider(height: 18, color: AppTheme.border(ctx)),
                            _buildDetailLine(
                              ctx,
                              'Giờ tăng ca (x1.5 / x2.0):',
                              '+${record.overtimeHours.toStringAsFixed(2)} giờ',
                              AppTheme.amber,
                            ),
                            Divider(height: 18, color: AppTheme.border(ctx)),
                            _buildDetailLine(
                              ctx,
                              'Tổng giờ làm việc thực tế:',
                              '${record.totalWorkingHours.toStringAsFixed(2)} giờ',
                              AppTheme.purple,
                            ),
                            Divider(height: 18, color: AppTheme.border(ctx)),
                            _buildDetailLine(
                              ctx,
                              'Hình thức chấm công:',
                              record.isHybrid
                                  ? 'Vào: Vân tay App • Ra: Quản lý bù'
                                  : (record.isManualEntry
                                      ? '100% Chấm bù thủ công'
                                      : '100% Vân tay chính chủ App'),
                              record.isHybrid
                                  ? const Color(0xFF6366F1)
                                  : (record.isManualEntry
                                      ? AppTheme.amber
                                      : AppTheme.emerald),
                            ),
                            if (record.isManualEntry &&
                                record.manualEntryByName != null &&
                                record.manualEntryByName!.isNotEmpty) ...[
                              Divider(height: 18, color: AppTheme.border(ctx)),
                              _buildDetailLine(
                                ctx,
                                'Người duyệt chấm bù:',
                                record.manualEntryByName!,
                                AppTheme.amber,
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (record.remarks != null &&
                          record.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.elevated(ctx),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border(ctx)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppTheme.textSecondary(ctx),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ghi chú: ${record.remarks}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary(ctx),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Đóng Chi Tiết',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailLine(
      BuildContext ctx, String label, String value, Color valColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(ctx),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: valColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final int distinctDays = _records
        .where((r) => r.checkInTime != null)
        .map((r) =>
            '${r.attendanceDate.year}-${r.attendanceDate.month}-${r.attendanceDate.day}')
        .toSet()
        .length;
    final double totalHours =
        _records.fold(0.0, (sum, r) => sum + r.totalWorkingHours);
    final double regularHours =
        _records.fold(0.0, (sum, r) => sum + r.regularHours);
    final double overtimeHours =
        _records.fold(0.0, (sum, r) => sum + r.overtimeHours);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lịch Sử & Thống Kê',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Theo dõi chi tiết ngày công theo Tuần / Tháng / Quý / Năm',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Period Filter Chips (Tuần / Tháng / Quý / Năm / Tất cả)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _buildFilterChip('Tuần này', 'Week'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Tháng này', 'Month'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Quý này', 'Quarter'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Năm nay', 'Year'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Tất cả', 'All'),
                ],
              ),
            ),

            // Summary Hero Card + Mini Visual Bar Chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Ngày công',
                            '$distinctDays ngày',
                            Colors.white,
                          ),
                        ),
                        Container(width: 1, height: 32, color: Colors.white24),
                        Expanded(
                          child: _buildStatItem(
                            'Tổng giờ làm',
                            '${totalHours.toStringAsFixed(1)}h',
                            const Color(0xFF38BDF8),
                          ),
                        ),
                        Container(width: 1, height: 32, color: Colors.white24),
                        Expanded(
                          child: _buildStatItem(
                            'Giờ chuẩn',
                            '${regularHours.toStringAsFixed(1)}h',
                            const Color(0xFF34D399),
                          ),
                        ),
                        Container(width: 1, height: 32, color: Colors.white24),
                        Expanded(
                          child: _buildStatItem(
                            'Tăng ca',
                            '+${overtimeHours.toStringAsFixed(1)}h',
                            const Color(0xFFFBBF24),
                          ),
                        ),
                      ],
                    ),
                    if (_records.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildMiniBarChart(_records.take(7).toList().reversed.toList()),
                    ],
                  ],
                ),
              ),
            ),

            // Records List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : _records.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy_rounded,
                                size: 54,
                                color: AppTheme.textSecondary(context)
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Không có bản ghi chấm công trong kỳ này',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: _loadHistory,
                          child: ListView.builder(
                            controller: _activeScrollController,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                            itemCount: _records.length,
                            itemBuilder: (context, index) {
                              final record = _records[index];
                              return StaggeredFadeSlide(
                                index: index,
                                child: AttendanceCard(
                                  record: record,
                                  onTap: () => _showRecordDetailSheet(record),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBarChart(List<AttendanceRecord> recent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Biểu đồ giờ làm các ngày gần nhất',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34D399),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Chuẩn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBBF24),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Tăng ca',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: recent.map((r) {
                final double maxH = 12.0;
                final double regRatio =
                    (r.regularHours / maxH).clamp(0.05, 1.0);
                final double otRatio = (r.overtimeHours / maxH).clamp(0.0, 0.5);
                final String dayLbl = DateFormat('dd/MM').format(r.attendanceDate);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${r.totalWorkingHours.toStringAsFixed(1)}h',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: (regRatio + otRatio).clamp(0.12, 1.0),
                            child: Container(
                              width: 16,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: r.overtimeHours > 0
                                      ? [
                                          const Color(0xFFFBBF24),
                                          const Color(0xFF34D399),
                                        ]
                                      : [
                                          const Color(0xFF34D399),
                                          const Color(0xFF059669),
                                        ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        dayLbl,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool isSelected = _filterType == value;
    return BounceTap(
      onTap: () {
        if (_filterType != value) {
          setState(() => _filterType = value);
          _loadHistory();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary(context),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
