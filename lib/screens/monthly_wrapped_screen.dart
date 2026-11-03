import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../models/monthly_wrapped_model.dart';
import '../models/salary_model.dart';
import '../services/attendance_service.dart';

class MonthlyWrappedScreen extends StatefulWidget {
  final int? year;
  final int? month;
  final List<AttendanceRecord>? records;
  final String? employeeName;
  final String? department;
  final double? estimatedSalary;

  const MonthlyWrappedScreen({
    super.key,
    this.year,
    this.month,
    this.records,
    this.employeeName,
    this.department,
    this.estimatedSalary,
  });

  static Future<void> show(
    BuildContext context, {
    int? year,
    int? month,
    List<AttendanceRecord>? records,
    String? employeeName,
    String? department,
    double? estimatedSalary,
  }) async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: MonthlyWrappedScreen(
            year: year,
            month: month,
            records: records,
            employeeName: employeeName,
            department: department,
            estimatedSalary: estimatedSalary,
          ),
        ),
      ),
    );
  }

  @override
  State<MonthlyWrappedScreen> createState() => _MonthlyWrappedScreenState();
}

class _MonthlyWrappedScreenState extends State<MonthlyWrappedScreen>
    with TickerProviderStateMixin {
  final AttendanceService _service = AttendanceService();
  MonthlyWrappedModel? _wrapped;
  bool _isLoading = true;
  int _currentSlide = 0;
  static const int _totalSlides = 5;

  late PageController _pageController;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPaused = false;

  // Background Aurora Gradients for 5 Chapters
  static const List<List<Color>> _slideGradients = [
    // 0. Work Streak & Consistency (Obsidian to Warm Amber Ember)
    [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF78350F)],
    // 1. Punctuality & Discipline (Midnight Navy to Deep Cyan)
    [Color(0xFF031024), Color(0xFF082F49), Color(0xFF0369A1)],
    // 2. Productivity & Peak Output (Charcoal to Electric Gold)
    [Color(0xFF18181B), Color(0xFF27272A), Color(0xFFB45309)],
    // 3. Workplace Persona & Department (Royal Slate to Indigo)
    [Color(0xFF0B0F19), Color(0xFF1E1B4B), Color(0xFF312E81)],
    // 4. Rewards & Milestone (Deep Emerald to Forest Green)
    [Color(0xFF031B13), Color(0xFF064E3B), Color(0xFF047857)],
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (_currentSlide < _totalSlides - 1) {
            _nextSlide();
          } else {
            _progressController.stop();
          }
        }
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final y = widget.year ?? now.year;
    final m = widget.month ?? now.month;

    List<AttendanceRecord> recs = widget.records ?? [];
    if (recs.isEmpty) {
      try {
        final firstDay = DateTime(y, m, 1);
        final lastDay = DateTime(y, m + 1, 0, 23, 59, 59);
        recs = await _service.getMyHistory(fromDate: firstDay, toDate: lastDay);
      } catch (_) {}
    }

    SalaryModel? salary;
    try {
      salary = await _service.getMySalary(
        periodType: 'Month',
        year: y,
        month: m,
      );
    } catch (_) {}

    final model = MonthlyWrappedModel.fromRecordsAndSalary(
      year: y,
      month: m,
      employeeName: widget.employeeName ?? salary?.fullName ?? 'Nguyễn Văn Phúc',
      department: widget.department ?? salary?.department ?? 'Phòng Kỹ Thuật',
      records: recs,
      salary: salary,
    );

    if (mounted) {
      setState(() {
        _wrapped = model;
        _isLoading = false;
      });
      _startStoryTimer();
    }
  }

  void _startStoryTimer() {
    if (!mounted) return;
    _progressController.reset();
    _progressController.forward();
  }

  void _pauseStory() {
    if (!_isPaused) {
      _isPaused = true;
      _progressController.stop();
    }
  }

  void _resumeStory() {
    if (_isPaused) {
      _isPaused = false;
      _progressController.forward();
    }
  }

  void _prevSlide() {
    HapticFeedback.selectionClick();
    if (_pageController.hasClients && (_pageController.page ?? _currentSlide) > 0) {
      _progressController.reset();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _startStoryTimer();
    }
  }

  void _nextSlide() {
    HapticFeedback.selectionClick();
    if (_pageController.hasClients &&
        (_pageController.page ?? _currentSlide) < _totalSlides - 1) {
      _progressController.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF38BDF8),
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Đang tổng hợp dữ liệu hành trình của bạn...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _wrapped!;
    final currentGradient =
        _slideGradients[_currentSlide % _slideGradients.length];

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: currentGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),

              // 1. SEGMENTED PROGRESS BARS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return Row(
                      children: List.generate(_totalSlides, (idx) {
                        double fill = 0.0;
                        if (idx < _currentSlide) {
                          fill = 1.0;
                        } else if (idx == _currentSlide) {
                          fill = _progressController.value;
                        }
                        return Expanded(
                          child: Container(
                            height: 3.5,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: fill,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: fill > 0
                                      ? [
                                          BoxShadow(
                                            color: Colors.white
                                                .withValues(alpha: 0.8),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),

              // 2. ELEGANT HEADER BAR (Independent Tap for Close Button)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Streak Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFB923C).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFFB923C),
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${data.longestStreak} Ngày chuỗi',
                            style: const TextStyle(
                              color: Color(0xFFFDBA74),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'DẤU ẤN THÁNG ${data.month}/${data.year} • NOVA CORP',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Close Button
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),

              // 3. MAIN SLIDE CONTENT WITH SWIPE & TOUCH NAVIGATION
              Expanded(
                child: Stack(
                  children: [
                    PageView(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (page) {
                        setState(() => _currentSlide = page);
                        if (page == _totalSlides - 1) {
                          _progressController.stop();
                          _progressController.value = 1.0;
                        } else {
                          _startStoryTimer();
                        }
                      },
                      children: [
                        _buildSlide0Streak(data),
                        _buildSlide1Punctuality(data),
                        _buildSlide2Productivity(data),
                        _buildSlide3Persona(data),
                        _buildSlide4Earnings(data),
                      ],
                    ),

                    // Gesture overlay on Slides 0-3 for rapid tap navigation
                    if (_currentSlide < _totalSlides - 1) ...[
                      // Left tap = prev
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: MediaQuery.of(context).size.width * 0.32,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _prevSlide,
                          onLongPressStart: (_) => _pauseStory(),
                          onLongPressEnd: (_) => _resumeStory(),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      // Right tap = next
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: MediaQuery.of(context).size.width * 0.68,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _nextSlide,
                          onLongPressStart: (_) => _pauseStory(),
                          onLongPressEnd: (_) => _resumeStory(),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SLIDE 0: 🔥 NGỌN LỬA CHUYÊN CẦN & CHUỖI CÔNG TÁC THỰC TẾ
  // =========================================================================
  Widget _buildSlide0Streak(MonthlyWrappedModel data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(
        children: [
          _buildUserHeader(data),
          const SizedBox(height: 18),

          // Pulsing Work Flame
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFFF7A00),
                    Color(0xFFE11D48),
                    Colors.transparent,
                  ],
                  stops: [0.35, 0.75, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withValues(alpha: 0.45),
                    blurRadius: 36,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Big Streak Number
          Text(
            '${data.longestStreak}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 68,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'NGÀY LÀM VIỆC LIÊN TIẾP ĐẠT ĐỈNH 🔥',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFDBA74),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Giai đoạn bứt phá: ${data.longestStreakRange}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Peak Week Calendar Track
          _buildGlassCard(
            borderColor: const Color(0xFFEA580C).withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            color: Color(0xFFFB923C), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'NHỊP ĐỘ TUẦN BÙNG NỔ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${data.longestStreak} Ngày công',
                      style: const TextStyle(
                        color: Color(0xFFFDBA74),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDayPill('T2', data.peakWeekStreakStatus[0]),
                    _buildDayPill('T3', data.peakWeekStreakStatus[1]),
                    _buildDayPill('T4', data.peakWeekStreakStatus[2]),
                    _buildDayPill('T5', data.peakWeekStreakStatus[3]),
                    _buildDayPill('T6', data.peakWeekStreakStatus[4]),
                    _buildDayPill('T7', data.peakWeekStreakStatus[5]),
                    _buildDayPill('CN', data.peakWeekStreakStatus[6], isWeekend: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Workday & Consistency Summary Card
          _buildGlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFF38BDF8),
                        title: 'Tổng Ngày Công',
                        value: '${data.totalWorkingDays} Ngày',
                        sub: 'Chuẩn ${data.standardWorkingDays} ngày',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.electric_bolt_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Chuỗi Hiện Tại',
                        value: '${data.currentStreak} Ngày',
                        sub: 'Tính đến hôm nay',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    data.streakComment,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      height: 1.4,
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

  // =========================================================================
  // SLIDE 1: ⏱️ TÁC PHONG & KỶ LUẬT ĐÚNG GIỜ
  // =========================================================================
  Widget _buildSlide1Punctuality(MonthlyWrappedModel data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(
        children: [
          _buildUserHeader(data),
          const SizedBox(height: 18),

          // Radar Clock Icon
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0284C7).withValues(alpha: 0.22),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.access_time_filled_rounded,
              color: Color(0xFF38BDF8),
              size: 58,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '${data.onTimePercentage.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const Text(
            'TỶ LỆ VÀO CA ĐÚNG GIỜ 🎯',
            style: TextStyle(
              color: Color(0xFF7DD3FC),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 22),

          // 2 Cards: Earliest Check-in & Average Check-in
          Row(
            children: [
              Expanded(
                child: _buildGlassCard(
                  borderColor: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wb_sunny_rounded,
                              color: Color(0xFFFDE047), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Sớm Nhất Tháng',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.earliestCheckInTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.earliestCheckInDate.isNotEmpty
                            ? 'Ngày ${data.earliestCheckInDate}'
                            : 'Trước giờ làm',
                        style: const TextStyle(
                          color: Color(0xFF7DD3FC),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlassCard(
                  borderColor: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.av_timer_rounded,
                              color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Vào Ca Trung Bình',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.averageCheckInTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Nhịp độ chuẩn xác',
                        style: TextStyle(
                          color: Color(0xFF7DD3FC),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Favorite Shift Card
          _buildGlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ca làm việc gắn bó nhất',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.favoriteShift,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SLIDE 2: ⚡ NĂNG SUẤT & NGÀY ĐỈNH CAO THỰC TẾ
  // =========================================================================
  Widget _buildSlide2Productivity(MonthlyWrappedModel data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(
        children: [
          _buildUserHeader(data),
          const SizedBox(height: 18),

          // Bolt Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD97706).withValues(alpha: 0.22),
              border: Border.all(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.7),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.45),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFFDE047),
              size: 58,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '${data.totalHours.toStringAsFixed(1)}h',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 66,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const Text(
            'TỔNG THỜI GIAN LÀM VIỆC THỰC TẾ ⚡',
            style: TextStyle(
              color: Color(0xFFFDE68A),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 22),

          // 2 Columns: Regular vs Overtime Hours
          _buildGlassCard(
            borderColor: const Color(0xFFB45309).withValues(alpha: 0.4),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF34D399),
                    title: 'Giờ Tiêu Chuẩn',
                    value: '${data.regularHours.toStringAsFixed(1)}h',
                    sub: 'Tối đa 8h / ngày',
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: _buildMetricItem(
                    icon: Icons.bolt_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    title: 'Giờ Tăng Ca',
                    value: '+${data.overtimeHours.toStringAsFixed(1)}h',
                    sub: 'Hệ số x1.5 / x2.0',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Peak Day Highlight Card
          _buildGlassCard(
            borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFFFDE047), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'NGÀY BỨT PHÁ CAO NHẤT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${data.mostProductiveDayHours.toStringAsFixed(1)} Giờ',
                        style: const TextStyle(
                          color: Color(0xFFFDE047),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data.mostProductiveDayOfWeek,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Đây là ngày bạn đạt thời lượng cống hiến lớn nhất trong tháng, hỗ trợ đắc lực cho tiến độ chung của đội ngũ.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SLIDE 3: 🎖️ ĐỊNH VỊ CÁ NHÂN & DẤU ẤN NHÂN SỰ
  // =========================================================================
  Widget _buildSlide3Persona(MonthlyWrappedModel data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(
        children: [
          _buildUserHeader(data),
          const SizedBox(height: 18),

          // Honor Medal Icon
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withValues(alpha: 0.22),
              border: Border.all(
                color: const Color(0xFF818CF8).withValues(alpha: 0.7),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.military_tech_rounded,
              color: Color(0xFFA5B4FC),
              size: 58,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            data.personaTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.personaSubtitle.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFA5B4FC),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 22),

          // Department & Role Card
          _buildGlassCard(
            borderColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.corporate_fare_rounded,
                          color: Color(0xFFA5B4FC), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data.jobTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  data.personalizedStory,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Highlights Card
          _buildGlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniPill(
                  Icons.schedule_rounded,
                  '${data.totalHours.toStringAsFixed(1)}h',
                  'Cống hiến',
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                _buildMiniPill(
                  Icons.bolt_rounded,
                  '+${data.overtimeHours.toStringAsFixed(1)}h',
                  'Tăng ca',
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                _buildMiniPill(
                  Icons.local_fire_department_rounded,
                  '${data.longestStreak} ngày',
                  'Chuỗi kỷ lục',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SLIDE 4: 💼 THÀNH QUẢ XỨNG ĐÁNG & LƯƠNG CHÍNH XÁC 100%
  // =========================================================================
  Widget _buildSlide4Earnings(MonthlyWrappedModel data) {
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(
        children: [
          _buildUserHeader(data),
          const SizedBox(height: 18),

          // Trophy / Star Icon
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF059669).withValues(alpha: 0.25),
              border: Border.all(
                color: const Color(0xFF34D399).withValues(alpha: 0.7),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.45),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFF6EE7B7),
              size: 58,
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'THÀNH QUẢ LAO ĐỘNG THÁNG 10/2026',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFA7F3D0),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),

          // Total Salary Big Number
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFmt.format(data.totalSalary),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Official Breakdown Card
          _buildGlassCard(
            borderColor: const Color(0xFF059669).withValues(alpha: 0.4),
            child: Column(
              children: [
                _buildSalaryRow(
                  label: 'Lương giờ tiêu chuẩn',
                  detail:
                      '${data.regularHours.toStringAsFixed(1)}h × ${NumberFormat('#,###', 'vi_VN').format(data.hourlyRate)}đ',
                  amount: currencyFmt.format(data.regularSalary),
                  amountColor: Colors.white,
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                _buildSalaryRow(
                  label: 'Lương tăng ca (OT x1.5)',
                  detail: '+${data.overtimeHours.toStringAsFixed(1)}h cống hiến',
                  amount: currencyFmt.format(data.overtimeSalary),
                  amountColor: const Color(0xFFFDE047),
                ),
                if (data.bonusSalary > 0) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  _buildSalaryRow(
                    label: 'Thưởng cống hiến',
                    detail: data.bonusReason ?? 'Thưởng chuyên cần',
                    amount: currencyFmt.format(data.bonusSalary),
                    amountColor: const Color(0xFF34D399),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Appreciation Message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              'Trân trọng cảm ơn ${data.employeeName} đã đồng hành và cống hiến vì sự phát triển của Nova Corp trong tháng ${data.month}/${data.year}. Chúc bạn luôn giữ vững phong độ và bứt phá thành công!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Primary Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF059669).withValues(alpha: 0.5),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'HOÀN TẤT & TIẾP TỤC HÀNH TRÌNH',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Share Button
          TextButton.icon(
            icon: const Icon(Icons.share_rounded,
                color: Colors.white70, size: 16),
            label: const Text(
              'Lưu hoặc chia sẻ dấu ấn tháng',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Đã lưu dấu ấn tháng ${data.month}/${data.year} của ${data.employeeName}!',
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF059669),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================
  Widget _buildUserHeader(MonthlyWrappedModel data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF2563EB),
            child: Text(
              data.employeeName.isNotEmpty ? data.employeeName[0] : 'N',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              data.employeeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (data.department?.isNotEmpty == true) ...[
            const SizedBox(width: 6),
            Text(
              '•  ${data.department}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.14),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDayPill(String label, bool isAttended, {bool isWeekend = false}) {
    Color bg;
    Color border;
    Widget icon;

    if (isAttended) {
      bg = const Color(0xFFF97316);
      border = const Color(0xFFFB923C);
      icon = const Icon(Icons.local_fire_department_rounded,
          color: Colors.white, size: 14);
    } else if (isWeekend) {
      bg = Colors.white.withValues(alpha: 0.05);
      border = Colors.white.withValues(alpha: 0.1);
      icon = const Text('•',
          style: TextStyle(color: Colors.white38, fontSize: 13));
    } else {
      bg = Colors.white.withValues(alpha: 0.04);
      border = Colors.white.withValues(alpha: 0.08);
      icon = const Text('—',
          style: TextStyle(color: Colors.white38, fontSize: 11));
    }

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isAttended ? const Color(0xFFFDBA74) : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
            boxShadow: isAttended
                ? [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Center(child: icon),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String sub,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildMiniPill(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSalaryRow({
    required String label,
    required String detail,
    required String amount,
    required Color amountColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              detail,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        Text(
          amount,
          style: TextStyle(
            color: amountColor,
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
