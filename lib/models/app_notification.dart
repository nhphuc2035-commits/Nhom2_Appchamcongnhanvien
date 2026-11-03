
enum NotificationType {
  checkIn,
  checkOut,
  salary,
  security,
  system,
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.type = NotificationType.system,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'isRead': isRead,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    NotificationType nType = NotificationType.system;
    try {
      final typeStr = json['type'] as String?;
      if (typeStr != null) {
        nType = NotificationType.values.firstWhere(
          (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
          orElse: () => NotificationType.system,
        );
      }
    } catch (_) {}

    DateTime time = DateTime.now();
    try {
      if (json['timestamp'] != null) {
        time = DateTime.parse(json['timestamp']);
      }
    } catch (_) {}

    return AppNotification(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'Thông báo',
      message: json['message'] ?? '',
      timestamp: time,
      type: nType,
      isRead: json['isRead'] == true,
    );
  }
}
