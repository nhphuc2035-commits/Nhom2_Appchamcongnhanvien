import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_notification.dart';
import '../services/notification_store.dart';
import '../theme/app_theme.dart';

class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationCenterSheet(),
    );
  }

  @override
  State<NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _filterUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await NotificationStore.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(AppNotification item) async {
    await NotificationStore.markAsRead(item.id);
    await _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    await NotificationStore.markAllAsRead();
    await _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đánh dấu tất cả thông báo là ĐÃ ĐỌC.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(ctx),
        title: const Text('Xóa toàn bộ thông báo?'),
        content: const Text(
            'Hành động này sẽ xóa sạch tất cả lịch sử thông báo trên thiết bị.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.rose,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa hết'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationStore.clearAll();
      await _loadNotifications();
    }
  }

  void _showNotificationDetail(AppNotification item) {
    _markAsRead(item);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            _buildTypeIcon(item.type, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('HH:mm • dd/MM/yyyy').format(item.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(ctx),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.message,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(NotificationType type, {double size = 20}) {
    Color bg;
    Color iconColor;
    IconData icon;

    switch (type) {
      case NotificationType.checkIn:
        bg = AppTheme.emerald.withValues(alpha: 0.15);
        iconColor = AppTheme.emerald;
        icon = Icons.login_rounded;
        break;
      case NotificationType.checkOut:
        bg = AppTheme.rose.withValues(alpha: 0.15);
        iconColor = AppTheme.rose;
        icon = Icons.logout_rounded;
        break;
      case NotificationType.salary:
        bg = AppTheme.amber.withValues(alpha: 0.15);
        iconColor = AppTheme.amber;
        icon = Icons.payments_rounded;
        break;
      case NotificationType.security:
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.15);
        iconColor = const Color(0xFF8B5CF6);
        icon = Icons.shield_rounded;
        break;
      case NotificationType.system:
        bg = AppTheme.primary.withValues(alpha: 0.15);
        iconColor = AppTheme.primary;
        icon = Icons.notifications_active_rounded;
        break;
    }

    return Container(
      width: size * 2,
      height: size * 2,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(icon, color: iconColor, size: size),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final displayedList = _filterUnreadOnly
        ? _notifications.where((n) => !n.isRead).toList()
        : _notifications;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppTheme.border(context),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppTheme.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Thông Báo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.rose,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Lịch sử nhắc nhở & chấm công',
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Đọc tất cả',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.done_all_rounded, size: 20),
                      color: AppTheme.primary,
                      onPressed: unreadCount > 0 ? _markAllAsRead : null,
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: 'Xóa tất cả',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: AppTheme.textSecondary(context),
                      onPressed: _notifications.isNotEmpty ? _clearAll : null,
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: 'Đóng',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.close_rounded, size: 21),
                      color: AppTheme.textSecondary(context),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('Tất cả (${_notifications.length})'),
                    selected: !_filterUnreadOnly,
                    onSelected: (val) {
                      if (val) setState(() => _filterUnreadOnly = false);
                    },
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: !_filterUnreadOnly
                          ? Colors.white
                          : AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Chưa đọc ($unreadCount)'),
                    selected: _filterUnreadOnly,
                    onSelected: (val) {
                      if (val) setState(() => _filterUnreadOnly = true);
                    },
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _filterUnreadOnly
                          ? Colors.white
                          : AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20),

          // Notification List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : displayedList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 54,
                              color: AppTheme.textSecondary(context)
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _filterUnreadOnly
                                  ? 'Không có thông báo chưa đọc nào.'
                                  : 'Bạn chưa có thông báo nào.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        itemCount: displayedList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = displayedList[index];
                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppTheme.rose,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_rounded,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) async {
                              await NotificationStore.deleteNotification(
                                  item.id);
                              await _loadNotifications();
                            },
                            child: Material(
                              color: item.isRead
                                  ? AppTheme.surface(context)
                                  : AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => _showNotificationDetail(item),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: item.isRead
                                          ? AppTheme.border(context)
                                          : AppTheme.primary
                                              .withValues(alpha: 0.35),
                                      width: item.isRead ? 1 : 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildTypeIcon(item.type, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: item.isRead
                                                          ? FontWeight.w700
                                                          : FontWeight.w900,
                                                      color: AppTheme.textPrimary(
                                                          context),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _formatTimeAgo(
                                                      item.timestamp),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppTheme.textSecondary(
                                                            context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              item.message,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: item.isRead
                                                    ? AppTheme.textSecondary(
                                                        context)
                                                    : AppTheme.textPrimary(
                                                        context),
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!item.isRead) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 4),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
