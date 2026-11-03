import 'package:intl/intl.dart';
import 'attendance_record.dart';
import 'salary_model.dart';

class MonthlyWrappedModel {
  final int year;
  final int month;
  final String employeeName;
  final String? department;
  final String jobTitle;

  // Real work statistics
  final double totalHours;
  final double regularHours;
  final double overtimeHours;
  final int totalWorkingDays;
  final int standardWorkingDays;
  final double onTimePercentage;
  final String averageCheckInTime;
  final String earliestCheckInTime;
  final String earliestCheckInDate;
  final String mostProductiveDayOfWeek;
  final double mostProductiveDayHours;
  final String favoriteShift;

  // Real Work Streak metrics
  final int longestStreak;
  final String longestStreakRange;
  final int currentStreak;
  final List<bool> peakWeekStreakStatus; // [T2, T3, T4, T5, T6, T7, CN]
  final String streakComment;

  // Real Salary details (100% matching SalaryScreen)
  final double totalSalary;
  final double regularSalary;
  final double overtimeSalary;
  final double bonusSalary;
  final String? bonusReason;
  final double hourlyRate;

  // Personalized Persona
  final String personaTitle;
  final String personaSubtitle;
  final String personalizedStory;

  const MonthlyWrappedModel({
    required this.year,
    required this.month,
    required this.employeeName,
    this.department,
    this.jobTitle = 'Nhân viên',
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.totalWorkingDays,
    this.standardWorkingDays = 27,
    required this.onTimePercentage,
    required this.averageCheckInTime,
    required this.earliestCheckInTime,
    required this.earliestCheckInDate,
    required this.mostProductiveDayOfWeek,
    required this.mostProductiveDayHours,
    required this.favoriteShift,
    required this.longestStreak,
    required this.longestStreakRange,
    required this.currentStreak,
    required this.peakWeekStreakStatus,
    required this.streakComment,
    required this.totalSalary,
    required this.regularSalary,
    required this.overtimeSalary,
    this.bonusSalary = 0.0,
    this.bonusReason,
    this.hourlyRate = 75000.0,
    required this.personaTitle,
    required this.personaSubtitle,
    required this.personalizedStory,
  });

  factory MonthlyWrappedModel.fromJson(Map<String, dynamic> json) {
    final double hours = (json['totalHours'] as num?)?.toDouble() ?? 0.0;
    final double otHours = (json['overtimeHours'] as num?)?.toDouble() ?? 0.0;
    final double regHours = (json['regularHours'] as num?)?.toDouble() ?? (hours - otHours);
    final int days = json['totalWorkingDays'] ?? 0;
    final double onTime = (json['onTimePercentage'] as num?)?.toDouble() ?? 100.0;

    return MonthlyWrappedModel(
      year: json['year'] ?? DateTime.now().year,
      month: json['month'] ?? DateTime.now().month,
      employeeName: json['employeeName'] ?? 'Nhân viên',
      department: json['department'],
      jobTitle: json['jobTitle'] ?? 'Nhân viên Nova Corp',
      totalHours: hours,
      regularHours: regHours > 0 ? regHours : hours,
      overtimeHours: otHours,
      totalWorkingDays: days,
      standardWorkingDays: json['standardWorkingDays'] ?? 27,
      onTimePercentage: onTime,
      averageCheckInTime: json['averageCheckInTime'] ?? '--:--',
      earliestCheckInTime: json['earliestCheckInTime'] ?? '--:--',
      earliestCheckInDate: json['earliestCheckInDate'] ?? '',
      mostProductiveDayOfWeek: json['mostProductiveDayOfWeek'] ?? 'Thứ Tư',
      mostProductiveDayHours: (json['mostProductiveDayHours'] as num?)?.toDouble() ?? 8.0,
      favoriteShift: json['favoriteShift'] ?? 'Ca Hành Chính (08:00 - 17:00)',
      longestStreak: json['longestStreak'] ?? (days > 0 ? days : 1),
      longestStreakRange: json['longestStreakRange'] ?? 'Trong tháng',
      currentStreak: json['currentStreak'] ?? 1,
      peakWeekStreakStatus: (json['peakWeekStreakStatus'] as List?)
              ?.map((e) => e == true)
              .toList() ??
          const [false, true, true, true, true, true, false],
      streakComment: json['streakComment'] ?? 'Duy trì nhịp độ làm việc ổn định trong tháng.',
      totalSalary: (json['totalSalary'] as num?)?.toDouble() ??
          (json['totalSalaryEstimated'] as num?)?.toDouble() ??
          0.0,
      regularSalary: (json['regularSalary'] as num?)?.toDouble() ?? 0.0,
      overtimeSalary: (json['overtimeSalary'] as num?)?.toDouble() ?? 0.0,
      bonusSalary: (json['bonusSalary'] as num?)?.toDouble() ?? 0.0,
      bonusReason: json['bonusReason'],
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 75000.0,
      personaTitle: json['personaTitle'] ?? 'Chiến Binh Bền Bỉ',
      personaSubtitle: json['personaSubtitle'] ?? 'Nỗ lực cống hiến vì tập thể',
      personalizedStory: json['personalizedStory'] ??
          'Cảm ơn bạn đã đồng hành và cống hiến hết mình cùng Nova Corp.',
    );
  }

  factory MonthlyWrappedModel.fromRecordsAndSalary({
    required int year,
    required int month,
    required String employeeName,
    String? department,
    String? jobTitle,
    required List<AttendanceRecord> records,
    SalaryModel? salary,
  }) {
    final double totalHours =
        salary?.totalWorkingHours ?? records.fold(0.0, (s, r) => s + r.totalWorkingHours);
    final double otHours =
        salary?.overtimeHours ?? records.fold(0.0, (s, r) => s + r.overtimeHours);
    final double regHours =
        salary?.regularHours ?? (totalHours - otHours).clamp(0.0, totalHours);

    final List<AttendanceRecord> checkedInRecords =
        records.where((r) => r.checkInTime != null).toList();

    // Map distinct calendar days
    final Map<DateTime, AttendanceRecord> dateToRecord = {};
    for (final r in checkedInRecords) {
      final d = DateTime(r.attendanceDate.year, r.attendanceDate.month, r.attendanceDate.day);
      dateToRecord[d] = r;
    }
    final sortedDates = dateToRecord.keys.toList()..sort();
    final int workingDays = salary?.workingDaysCount ?? sortedDates.length;

    // Check-in analysis: average, earliest, punctuality
    int onTimeCount = 0;
    final List<int> checkInMins = [];
    int earliestMin = 9999;
    DateTime? earliestCheckInDt;

    for (final r in checkedInRecords) {
      final t = r.checkInTime!;
      final m = t.hour * 60 + t.minute;
      checkInMins.add(m);

      if (m < earliestMin) {
        earliestMin = m;
        earliestCheckInDt = t;
      }

      if (r.remarks?.contains('[Vào ca đúng giờ]') == true ||
          (t.hour < 8 || (t.hour == 8 && t.minute <= 15))) {
        onTimeCount++;
      }
    }

    final double onTimePct = checkInMins.isNotEmpty
        ? ((onTimeCount / checkInMins.length) * 100)
        : 100.0;

    String avgCheckInStr = '--:--';
    if (checkInMins.isNotEmpty) {
      final int avgM = (checkInMins.reduce((a, b) => a + b) / checkInMins.length).round();
      avgCheckInStr =
          '${(avgM ~/ 60).toString().padLeft(2, '0')}:${(avgM % 60).toString().padLeft(2, '0')}';
    }

    String earliestTimeStr = '--:--';
    String earliestDateStr = '';
    if (earliestCheckInDt != null) {
      earliestTimeStr = DateFormat('HH:mm').format(earliestCheckInDt);
      earliestDateStr = DateFormat('dd/MM').format(earliestCheckInDt);
    }

    // Most productive day (highest working hours on a single calendar day)
    String bestDayOfWeek = 'Thứ Năm';
    double bestDayHours = 0.0;
    for (final r in records) {
      if (r.totalWorkingHours > bestDayHours) {
        bestDayHours = r.totalWorkingHours;
        final wd = r.attendanceDate.weekday;
        final dateStr = DateFormat('dd/MM').format(r.attendanceDate);
        switch (wd) {
          case DateTime.monday:
            bestDayOfWeek = 'Thứ Hai ($dateStr)';
            break;
          case DateTime.tuesday:
            bestDayOfWeek = 'Thứ Ba ($dateStr)';
            break;
          case DateTime.wednesday:
            bestDayOfWeek = 'Thứ Tư ($dateStr)';
            break;
          case DateTime.thursday:
            bestDayOfWeek = 'Thứ Năm ($dateStr)';
            break;
          case DateTime.friday:
            bestDayOfWeek = 'Thứ Sáu ($dateStr)';
            break;
          case DateTime.saturday:
            bestDayOfWeek = 'Thứ Bảy ($dateStr)';
            break;
          default:
            bestDayOfWeek = 'Chủ Nhật ($dateStr)';
        }
      }
    }

    // Favorite shift
    final Map<String, int> shiftCounts = {};
    for (final r in records) {
      shiftCounts[r.shiftName] = (shiftCounts[r.shiftName] ?? 0) + 1;
    }
    String favShift = 'Ca Hành Chính (08:00 - 17:00)';
    int maxSc = -1;
    shiftCounts.forEach((k, v) {
      if (v > maxSc) {
        maxSc = v;
        favShift = k;
      }
    });

    // -------------------------------------------------------------------------
    // ACCURATE WORK STREAK CALCULATION (Respects Mon-Sat workweek, Sunday off)
    // -------------------------------------------------------------------------
    int maxStreak = 0;
    int curStreak = 0;
    DateTime? streakStart;
    DateTime? maxStreakStart;
    DateTime? maxStreakEnd;
    DateTime? prevDate;

    for (final d in sortedDates) {
      if (prevDate == null) {
        curStreak = 1;
        streakStart = d;
      } else {
        final diff = d.difference(prevDate).inDays;
        final isConsecutiveWorkday = (diff == 1) ||
            (diff == 2 && prevDate.weekday == DateTime.saturday && d.weekday == DateTime.monday);

        if (isConsecutiveWorkday) {
          curStreak++;
        } else {
          if (curStreak > maxStreak) {
            maxStreak = curStreak;
            maxStreakStart = streakStart;
            maxStreakEnd = prevDate;
          }
          curStreak = 1;
          streakStart = d;
        }
      }
      prevDate = d;
    }
    if (curStreak > maxStreak) {
      maxStreak = curStreak;
      maxStreakStart = streakStart;
      maxStreakEnd = prevDate;
    }

    if (maxStreak == 0 && workingDays > 0) {
      maxStreak = 1;
      maxStreakStart = sortedDates.isNotEmpty ? sortedDates.first : DateTime.now();
      maxStreakEnd = maxStreakStart;
    }

    String streakRangeStr = 'Trong tháng';
    if (maxStreakStart != null && maxStreakEnd != null) {
      final f = DateFormat('dd/MM');
      streakRangeStr = maxStreakStart == maxStreakEnd
          ? f.format(maxStreakStart)
          : '${f.format(maxStreakStart)} – ${f.format(maxStreakEnd)}';
    }

    // Current active streak (checking if last recorded workday connects to today)
    int finalCurrentStreak = 1;
    if (sortedDates.isNotEmpty) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final lastWorked = sortedDates.last;
      final diffFromToday = today.difference(lastWorked).inDays;
      if (diffFromToday <= 1 ||
          (diffFromToday == 2 && lastWorked.weekday == DateTime.saturday && today.weekday == DateTime.monday)) {
        finalCurrentStreak = curStreak > 0 ? curStreak : 1;
      } else {
        finalCurrentStreak = 1;
      }
    }

    // Peak week streak status (T2 -> CN of the longest streak week)
    final List<bool> peakWeekStatus = [false, false, false, false, false, false, false];
    if (maxStreakStart != null) {
      final mondayOfPeakWeek =
          maxStreakStart.subtract(Duration(days: maxStreakStart.weekday - 1));
      for (int i = 0; i < 7; i++) {
        final checkDay = mondayOfPeakWeek.add(Duration(days: i));
        final hasAttended = sortedDates.any((d) =>
            d.year == checkDay.year && d.month == checkDay.month && d.day == checkDay.day);
        peakWeekStatus[i] = hasAttended;
      }
    }

    String streakMsg = 'Duy trì nhịp độ làm việc ổn định tại Nova Corp.';
    if (maxStreak >= 5) {
      streakMsg =
          'Tuần lễ $streakRangeStr ghi dấu chuỗi $maxStreak ngày công liên tiếp, thể hiện sự cống hiến bền bỉ.';
    } else if (maxStreak >= 3) {
      streakMsg = 'Chuỗi $maxStreak ngày làm việc liền kề ($streakRangeStr) tạo nhịp độ công tác vững chắc.';
    }

    // -------------------------------------------------------------------------
    // SALARY DATA (100% Matching SalaryScreen)
    // -------------------------------------------------------------------------
    final double hourlyRate = salary?.hourlyRate ?? 75000.0;
    final double regularSalary =
        salary?.regularSalary ?? (regHours * hourlyRate);
    final double overtimeSalary =
        salary?.overtimeSalary ?? (otHours * hourlyRate * (salary?.overtimeMultiplier ?? 1.5));
    final double bonusSalary = salary?.bonusSalary ?? 0.0;
    final double totalSalary =
        salary?.totalSalary ?? (regularSalary + overtimeSalary + bonusSalary);

    // -------------------------------------------------------------------------
    // PERSONALIZED PERSONA & NARRATIVE (Custom tailored to this individual)
    // -------------------------------------------------------------------------
    final resolvedJob = jobTitle ??
        (department?.isNotEmpty == true ? '$department' : 'Lập trình viên Backend');

    String persona;
    String personaSub;
    String narrative;

    if (otHours >= 1.0 && maxStreak >= 4) {
      persona = 'Chiến Binh Bền Bỉ';
      personaSub = 'Tận Tụy & Sẵn Sàng Bứt Phá';
      narrative =
          'Với $workingDays ngày công, ${totalHours.toStringAsFixed(1)} giờ làm việc và +${otHours.toStringAsFixed(1)}h tăng ca, bạn là điểm tựa vững chãi đảm bảo tiến độ và chất lượng công việc cho $resolvedJob tại Nova Corp.';
    } else if (onTimePct >= 90.0) {
      persona = 'Gương Mặt Chuẩn Mực';
      personaSub = 'Kỷ Luật Thép & Tác Phong Chuẩn Mực';
      narrative =
          'Tỷ lệ đúng giờ đạt ${onTimePct.toStringAsFixed(0)}% cùng giờ vào ca trung bình $avgCheckInStr minh chứng cho tác phong làm việc chuẩn mực, chuyên nghiệp đáng tự hào.';
    } else if (workingDays >= 15) {
      persona = 'Cột Trụ Vững Vàng';
      personaSub = 'Đồng Hành Kiên Định Cùng Đội Ngũ';
      narrative =
          'Sự hiện diện đều đặn và tinh thần trách nhiệm của bạn trong suốt $workingDays ngày công là nền tảng quan trọng cho mọi mục tiêu chung của Nova Corp.';
    } else {
      persona = 'Khởi Đầu Triển Vọng';
      personaSub = 'Từng Bước Vững Chắc Cùng Doanh Nghiệp';
      narrative =
          'Mỗi giờ làm việc và mỗi ngày công là một bước tiến quan trọng. Chúc $employeeName tiếp tục giữ vững nhiệt huyết để gặt hái thêm nhiều bước tiến mới trong tháng tiếp theo.';
    }

    return MonthlyWrappedModel(
      year: year,
      month: month,
      employeeName: employeeName,
      department: department,
      jobTitle: resolvedJob,
      totalHours: totalHours,
      regularHours: regHours,
      overtimeHours: otHours,
      totalWorkingDays: workingDays,
      standardWorkingDays: salary?.standardWorkingDays ?? 27,
      onTimePercentage: onTimePct,
      averageCheckInTime: avgCheckInStr,
      earliestCheckInTime: earliestTimeStr,
      earliestCheckInDate: earliestDateStr,
      mostProductiveDayOfWeek: bestDayOfWeek,
      mostProductiveDayHours: bestDayHours,
      favoriteShift: favShift,
      longestStreak: maxStreak,
      longestStreakRange: streakRangeStr,
      currentStreak: finalCurrentStreak,
      peakWeekStreakStatus: peakWeekStatus,
      streakComment: streakMsg,
      totalSalary: totalSalary,
      regularSalary: regularSalary,
      overtimeSalary: overtimeSalary,
      bonusSalary: bonusSalary,
      bonusReason: salary?.bonusReason,
      hourlyRate: hourlyRate,
      personaTitle: persona,
      personaSubtitle: personaSub,
      personalizedStory: narrative,
    );
  }
}
