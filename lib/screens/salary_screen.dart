import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/salary_model.dart';
import '../services/api_client.dart';
import '../services/attendance_service.dart';
import '../widgets/modern_animated_dialogs.dart';
import '../theme/app_theme.dart';
import '../widgets/staggered_animations.dart';
import 'monthly_wrapped_screen.dart';

class SalaryScreen extends StatefulWidget {
  final ScrollController? scrollController;

  const SalaryScreen({
    super.key,
    this.scrollController,
  });

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ScrollController? _internalScrollController;
  ScrollController get _activeScrollController =>
      widget.scrollController ??
      (_internalScrollController ??= ScrollController());

  final AttendanceService _attendanceService = AttendanceService();
  SalaryModel? _salary;
  bool _isLoading = true;
  bool _isSendingEmail = false;

  String _periodType = 'Month'; // 'Month' | 'Week'
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedWeek;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedWeek = _isoWeekNumber(now);
    _loadSalary();
  }

  @override
  void dispose() {
    _internalScrollController?.dispose();
    super.dispose();
  }

  int _isoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    final woy = ((dayOfYear - date.weekday + 10) ~/ 7);
    if (woy < 1) return 52;
    if (woy > 52) return 52;
    return woy;
  }

  Future<void> _loadSalary() async {
    setState(() => _isLoading = true);

    final data = await _attendanceService.getMySalary(
      periodType: _periodType,
      year: _selectedYear,
      month: _periodType == 'Month' ? _selectedMonth : null,
      weekNumber: _periodType == 'Week' ? _selectedWeek : null,
    );

    if (mounted) {
      setState(() {
        _salary = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSendEmailReport() async {
    setState(() => _isSendingEmail = true);

    final result = await _attendanceService.sendMyReportEmail(
      periodType: _periodType,
      year: _selectedYear,
      month: _periodType == 'Month' ? _selectedMonth : null,
      weekNumber: _periodType == 'Week' ? _selectedWeek : null,
    );

    if (!mounted) return;
    setState(() => _isSendingEmail = false);

    final msg = result['message'] ?? 'Đã gửi báo cáo thống kê & lương qua email!';
    if (ApiClient.isNetworkError(msg)) {
      ModernAnimatedDialogs.showNoInternetDialog(context: context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            result['success'] == true ? AppTheme.emerald : AppTheme.rose,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _changePeriodOffset(int delta) {
    setState(() {
      if (_periodType == 'Month') {
        int newMonth = _selectedMonth + delta;
        if (newMonth < 1) {
          _selectedMonth = 12;
          _selectedYear -= 1;
        } else if (newMonth > 12) {
          _selectedMonth = 1;
          _selectedYear += 1;
        } else {
          _selectedMonth = newMonth;
        }
      } else {
        int newWeek = _selectedWeek + delta;
        if (newWeek < 1) {
          _selectedWeek = 52;
          _selectedYear -= 1;
        } else if (newWeek > 52) {
          _selectedWeek = 1;
          _selectedYear += 1;
        } else {
          _selectedWeek = newWeek;
        }
      }
    });
    _loadSalary();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currencyFmt = NumberFormat('#,###', 'vi_VN');
    final totalSal = _salary?.totalSalary ?? 0.0;
    final regSal = _salary?.regularSalary ?? 0.0;
    final otSal = _salary?.overtimeSalary ?? 0.0;
    final double regPercent =
        totalSal > 0 ? (regSal / totalSal).clamp(0.0, 1.0) : 1.0;

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
                          'Bảng Lương & Báo Cáo',
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
                          'Tính lương tự động theo giờ tiêu chuẩn & tăng ca (x1.5)',
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
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => MonthlyWrappedScreen.show(
                      context,
                      year: _selectedYear,
                      month: _selectedMonth,
                      employeeName: _salary?.fullName,
                      department: _salary?.department,
                      estimatedSalary: _salary?.totalSalary,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Wrapped',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Toggle: Lương Tháng vs Lương Tuần + Period Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border(context)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModeTab('Theo Tháng', 'Month'),
                          ),
                          Expanded(
                            child: _buildModeTab('Theo Tuần', 'Week'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _changePeriodOffset(-1),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              size: 20,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            _periodType == 'Month'
                                ? 'T$_selectedMonth/$_selectedYear'
                                : 'Tuần $_selectedWeek/$_selectedYear',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _changePeriodOffset(1),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _loadSalary,
                      child: SingleChildScrollView(
                        controller: _activeScrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Thông báo đặc thù ngày vào làm / gia nhập giữa kỳ
                            if (_salary?.hireNote != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF0284C7)
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.badge_outlined,
                                      color: Color(0xFF38BDF8),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _salary!.hireNote!,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 1. Hero Total Salary Card
                            StaggeredFadeSlide(
                              index: 0,
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF059669),
                                      Color(0xFF0D9488),
                                      Color(0xFF0284C7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF059669)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _periodType == 'Month'
                                          ? 'TỔNG LƯƠNG THÁNG $_selectedMonth/$_selectedYear'
                                          : 'TỔNG LƯƠNG TUẦN $_selectedWeek/$_selectedYear',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white70,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: AnimatedNumberText(
                                        value: totalSal,
                                        formatter: (v) =>
                                            '${currencyFmt.format(v.round())} VNĐ',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Đơn giá: ${currencyFmt.format(_salary?.hourlyRate ?? 55000)} đ/giờ',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Hệ số tăng ca: Ngày thường x${_salary?.overtimeMultiplier ?? 1.5} • CN x2.0',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Lịch chuẩn: Thứ 2 – Thứ 7 (CN Nghỉ)',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. Salary Breakdown Card
                            StaggeredFadeSlide(
                              index: 1,
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface(context),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                      color: AppTheme.border(context)),
                                  boxShadow: AppTheme.softShadow(context),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chi tiết cấu thành tiền lương',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Visual Proportion Bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        height: 10,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: (regPercent * 100)
                                                  .round()
                                                  .clamp(1, 100),
                                              child: Container(
                                                  color: AppTheme.emerald),
                                            ),
                                            if (otSal > 0)
                                              Expanded(
                                                flex: ((1.0 - regPercent) * 100)
                                                    .round()
                                                    .clamp(1, 100),
                                                child: Container(
                                                    color: AppTheme.amber),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    _buildDetailRow(
                                      context,
                                      'Số ngày công đi làm',
                                      '${_salary?.workingDaysCount ?? 0} / ${_salary?.standardWorkingDays ?? 26} ngày',
                                      Icons.calendar_today_rounded,
                                      AppTheme.primary,
                                      subLabel: 'Lịch chuẩn: Thứ 2 – Thứ 7 (CN Nghỉ)',
                                    ),
                                    _buildDetailRow(
                                      context,
                                      'Tổng số giờ làm thực tế',
                                      '${(_salary?.totalWorkingHours ?? 0).toStringAsFixed(2)} giờ',
                                      Icons.schedule_rounded,
                                      AppTheme.primary,
                                    ),
                                    _buildDetailRow(
                                      context,
                                      'Giờ tiêu chuẩn (tối đa 8h/ngày)',
                                      '${(_salary?.regularHours ?? 0).toStringAsFixed(2)} giờ',
                                      Icons.check_circle_outline_rounded,
                                      AppTheme.emerald,
                                    ),
                                    _buildDetailRow(
                                      context,
                                      'Giờ tăng ca',
                                      '+${(_salary?.overtimeHours ?? 0).toStringAsFixed(2)} giờ',
                                      Icons.bolt_rounded,
                                      AppTheme.amber,
                                      subLabel: 'Ngày thường x1.5 • Chủ Nhật x2.0',
                                      valueColor: AppTheme.amber,
                                    ),
                                    Divider(
                                        height: 22,
                                        color: AppTheme.border(context)),
                                    _buildDetailRow(
                                      context,
                                      'Lương giờ hành chính',
                                      '${currencyFmt.format(regSal.round())} đ',
                                      Icons.payments_outlined,
                                      AppTheme.emerald,
                                    ),
                                    _buildDetailRow(
                                      context,
                                      'Lương tăng ca làm thêm',
                                      '+${currencyFmt.format(otSal.round())} đ',
                                      Icons.trending_up_rounded,
                                      AppTheme.amber,
                                    ),
                                    if ((_salary?.bonusSalary ?? 0) > 0)
                                      _buildDetailRow(
                                        context,
                                        'Thưởng cống hiến & đóng góp',
                                        '+${currencyFmt.format((_salary?.bonusSalary ?? 0).round())} đ',
                                        Icons.stars_rounded,
                                        AppTheme.emerald,
                                        subLabel: _salary?.bonusReason ?? 'Thưởng đóng góp đặc biệt trong kỳ',
                                        valueColor: AppTheme.emerald,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 3. Send Email Report Button
                            StaggeredFadeSlide(
                              index: 2,
                              child: BounceTap(
                                onTap: _isSendingEmail
                                    ? null
                                    : _handleSendEmailReport,
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppTheme.primary,
                                        AppTheme.primaryDark
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (_isSendingEmail)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else
                                          const Icon(
                                            Icons.mark_email_read_outlined,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              _isSendingEmail
                                                  ? 'ĐANG GỬI PHIẾU LƯƠNG...'
                                                  : 'NHẬN BÁO CÁO & PHIẾU LƯƠNG QUA EMAIL',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 4. Daily Salary Breakdown List
                            if (_salary != null &&
                                _salary!.dailyBreakdown.isNotEmpty) ...[
                              Text(
                                'Bảng kê lương chi tiết từng ngày (${_salary!.dailyBreakdown.length} ngày)',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ..._salary!.dailyBreakdown
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final d = entry.value;
                                final inStr = d.checkInTime != null
                                    ? DateFormat('HH:mm').format(d.checkInTime!)
                                    : '--:--';
                                final outStr = d.checkOutTime != null
                                    ? DateFormat('HH:mm')
                                        .format(d.checkOutTime!)
                                    : '--:--';
                                return StaggeredFadeSlide(
                                  index: 3 + entry.key,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface(context),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: AppTheme.border(context)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            DateFormat('dd/MM').format(d.date),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Ca: $inStr → $outStr',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textPrimary(
                                                      context),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Chuẩn: ${d.regularHours.toStringAsFixed(2)}h  •  Tăng ca: +${d.overtimeHours.toStringAsFixed(2)}h',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppTheme.textSecondary(
                                                      context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '+${currencyFmt.format(d.amount.round())} đ',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.emerald,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, String value) {
    final bool selected = _periodType == value;
    return GestureDetector(
      onTap: () {
        if (_periodType != value) {
          setState(() => _periodType = value);
          _loadSalary();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color iconColor, {
    String? subLabel,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
