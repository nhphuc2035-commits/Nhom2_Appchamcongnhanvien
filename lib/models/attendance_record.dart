class AttendanceRecord {
  final int id;
  final String userId;
  final String employeeName;
  final String? department;
  final String shiftName;
  final DateTime attendanceDate;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double totalWorkingHours;
  final String authenticationMethod;
  final bool isManualEntry;
  final String? manualEntryByName;
  final String? proofImagePath;
  final String? remarks;
  final String status;
  final String? entryType;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.employeeName,
    this.department,
    this.shiftName = 'Ca Hành Chính (08:00 - 17:00)',
    required this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    required this.totalWorkingHours,
    required this.authenticationMethod,
    required this.isManualEntry,
    this.manualEntryByName,
    this.proofImagePath,
    this.remarks,
    this.status = 'Completed',
    this.entryType,
  });

  bool get isSunday => attendanceDate.weekday == DateTime.sunday;

  bool get isHybrid =>
      entryType == 'Hybrid' ||
      authenticationMethod == 'Hybrid' ||
      (isManualEntry && proofImagePath != null && proofImagePath!.isNotEmpty);

  bool get isPureManual => isManualEntry && !isHybrid;

  double get regularHours {
    if (isSunday) return 0.0;
    return totalWorkingHours <= 8.0 ? totalWorkingHours : 8.0;
  }

  double get overtimeHours {
    if (isSunday) return totalWorkingHours;
    return totalWorkingHours > 8.0 ? (totalWorkingHours - 8.0) : 0.0;
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      department: json['department'],
      shiftName: json['shiftName'] ?? 'Ca Hành Chính (08:00 - 17:00)',
      attendanceDate: json['attendanceDate'] != null
          ? DateTime.parse(json['attendanceDate'])
          : DateTime.now(),
      checkInTime: json['checkInTime'] != null
          ? DateTime.parse(json['checkInTime'])
          : null,
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'])
          : null,
      totalWorkingHours: json['totalWorkingHours'] != null
          ? (json['totalWorkingHours'] as num).toDouble()
          : 0.0,
      authenticationMethod: json['authenticationMethod'] ?? 'Fingerprint',
      isManualEntry: json['isManualEntry'] ?? false,
      manualEntryByName: json['manualEntryByName'],
      proofImagePath: json['proofImagePath'],
      remarks: json['remarks'],
      status: json['status'] ??
          (json['checkOutTime'] != null ? 'Completed' : 'Working'),
      entryType: json['entryType'],
    );
  }
}
