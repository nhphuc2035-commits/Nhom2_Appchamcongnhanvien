class SalaryDailyItem {
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double hours;
  final double regularHours;
  final double overtimeHours;
  final double amount;
  final bool isManual;
  final bool isWeekend;
  final double dayMultiplier;

  SalaryDailyItem({
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.hours,
    required this.regularHours,
    required this.overtimeHours,
    required this.amount,
    required this.isManual,
    this.isWeekend = false,
    this.dayMultiplier = 1.0,
  });

  factory SalaryDailyItem.fromJson(Map<String, dynamic> json) {
    return SalaryDailyItem(
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'])
          : null,
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'])
          : null,
      hours: (json['hours'] as num?)?.toDouble() ?? 0.0,
      regularHours: (json['regularHours'] as num?)?.toDouble() ?? 0.0,
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      isManual: json['isManual'] ?? false,
      isWeekend: json['isWeekend'] ?? false,
      dayMultiplier: (json['dayMultiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class SalaryModel {
  final String userId;
  final String fullName;
  final String email;
  final String? department;
  final String periodType;
  final String periodDescription;
  final DateTime fromDate;
  final DateTime toDate;
  final int standardWorkingDays;
  final int workingDaysCount;
  final double totalWorkingHours;
  final double regularHours;
  final double overtimeHours;
  final double standardDailyHours;
  final double hourlyRate;
  final double overtimeMultiplier;
  final double regularSalary;
  final double overtimeSalary;
  final double bonusSalary;
  final String? bonusReason;
  final double totalSalary;
  final int incompleteRecords;
  final DateTime? hireDate;
  final String? hireNote;
  final List<SalaryDailyItem> dailyBreakdown;

  SalaryModel({
    required this.userId,
    required this.fullName,
    required this.email,
    this.department,
    this.periodType = 'Month',
    required this.periodDescription,
    required this.fromDate,
    required this.toDate,
    this.standardWorkingDays = 26,
    required this.workingDaysCount,
    required this.totalWorkingHours,
    required this.regularHours,
    required this.overtimeHours,
    this.standardDailyHours = 8.0,
    required this.hourlyRate,
    required this.overtimeMultiplier,
    required this.regularSalary,
    required this.overtimeSalary,
    this.bonusSalary = 0.0,
    this.bonusReason,
    required this.totalSalary,
    this.incompleteRecords = 0,
    this.hireDate,
    this.hireNote,
    this.dailyBreakdown = const [],
  });

  factory SalaryModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['dailyBreakdown'] is List
        ? (json['dailyBreakdown'] as List)
        : const [];

    return SalaryModel(
      userId: json['userId'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      department: json['department'],
      periodType: json['periodType'] ?? 'Month',
      periodDescription: json['periodDescription'] ?? '',
      fromDate: json['fromDate'] != null
          ? DateTime.parse(json['fromDate'])
          : DateTime.now(),
      toDate: json['toDate'] != null
          ? DateTime.parse(json['toDate'])
          : DateTime.now(),
      standardWorkingDays: json['standardWorkingDays'] ?? 26,
      workingDaysCount: json['workingDaysCount'] ?? 0,
      totalWorkingHours: (json['totalWorkingHours'] as num?)?.toDouble() ?? 0.0,
      regularHours: (json['regularHours'] as num?)?.toDouble() ?? 0.0,
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0.0,
      standardDailyHours: (json['standardDailyHours'] as num?)?.toDouble() ?? 8.0,
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 55000.0,
      overtimeMultiplier: (json['overtimeMultiplier'] as num?)?.toDouble() ?? 1.5,
      regularSalary: (json['regularSalary'] as num?)?.toDouble() ?? 0.0,
      overtimeSalary: (json['overtimeSalary'] as num?)?.toDouble() ?? 0.0,
      bonusSalary: (json['bonusSalary'] as num?)?.toDouble() ?? 0.0,
      bonusReason: json['bonusReason'],
      totalSalary: (json['totalSalary'] as num?)?.toDouble() ?? 0.0,
      incompleteRecords: json['incompleteRecords'] ?? 0,
      hireDate: json['hireDate'] != null ? DateTime.parse(json['hireDate']) : null,
      hireNote: json['hireNote'],
      dailyBreakdown: rawList
          .whereType<Map<String, dynamic>>()
          .map(SalaryDailyItem.fromJson)
          .toList(),
    );
  }
}
