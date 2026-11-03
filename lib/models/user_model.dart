class UserModel {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? department;
  final String? position;
  final String? assignedShift;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? address;
  final String? citizenId;
  final DateTime? hireDate;
  final bool isActive;
  final String role;
  final double? currentHourlyRate;
  final double? overtimeRateMultiplier;
  final double? standardDailyHours;
  final bool isBiometricEnrolled;
  final DateTime? biometricEnrolledAt;
  final String? biometricDeviceId;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.department,
    this.position,
    this.assignedShift,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.citizenId,
    this.hireDate,
    this.isActive = true,
    required this.role,
    this.currentHourlyRate,
    this.overtimeRateMultiplier,
    this.standardDailyHours,
    this.isBiometricEnrolled = false,
    this.biometricEnrolledAt,
    this.biometricDeviceId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['userId'] ?? '',
      username: json['username'] ?? json['userName'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'],
      department: json['department'],
      position: json['position'],
      assignedShift: json['assignedShift'] ?? 'Ca Hành Chính (08:00 - 17:00)',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'].toString())
          : null,
      gender: json['gender'],
      address: json['address'],
      citizenId: json['citizenId'],
      hireDate: json['hireDate'] != null
          ? DateTime.tryParse(json['hireDate'].toString())
          : null,
      isActive: json['isActive'] ?? true,
      role: json['role'] ?? 'User',
      currentHourlyRate: json['currentHourlyRate'] != null
          ? (json['currentHourlyRate'] as num).toDouble()
          : 55000.0,
      overtimeRateMultiplier: json['overtimeRateMultiplier'] != null
          ? (json['overtimeRateMultiplier'] as num).toDouble()
          : 1.5,
      standardDailyHours: json['standardDailyHours'] != null
          ? (json['standardDailyHours'] as num).toDouble()
          : 8.0,
      isBiometricEnrolled: json['isBiometricEnrolled'] ?? false,
      biometricEnrolledAt: json['biometricEnrolledAt'] != null
          ? DateTime.tryParse(json['biometricEnrolledAt'].toString())
          : null,
      biometricDeviceId: json['biometricDeviceId'],
    );
  }
}
