import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:your_creative_notebook/models/notification_item.dart';
import 'package:your_creative_notebook/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.initialize();
      setState(() {
        _notifications = _notificationService.notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat notifikasi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    await _notificationService.markAsRead(id);
    setState(() {
      _notifications = _notificationService.notifications;
    });
  }

  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead();
    setState(() {
      _notifications = _notificationService.notifications;
    });
  }

  Future<void> _deleteNotification(String id) async {
    await _notificationService.deleteNotification(id);
    setState(() {
      _notifications = _notificationService.notifications;
    });
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Semua Notifikasi'),
        content: const Text('Apakah Anda yakin ingin menghapus semua notifikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationService.clearAllNotifications();
      setState(() {
        _notifications = _notificationService.notifications;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((notification) => !notification.isRead).length;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unreadCount > 0)
              Text(
                '$unreadCount belum dibaca',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Tandai Semua'),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _clearAllNotifications();
                  break;
                case 'test_notification':
                  _notificationService.showTestNotification();
                  break;
                case 'refresh':
                  _loadNotifications();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test_notification',
                child: Row(
                  children: [
                    Icon(Icons.bug_report),
                    SizedBox(width: 8),
                    Text('Test Notifikasi'),
                  ],
                ),
              ),
              if (_notifications.isNotEmpty)
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Hapus Semua', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak Ada Notifikasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua notifikasi akan muncul di sini',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _notificationService.showTestNotification(),
            icon: const Icon(Icons.bug_report),
            label: const Text('Test Notifikasi'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return Dismissible(
            key: Key(notification.id),
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              color: Colors.blue,
              child: const Icon(
                Icons.mark_email_read,
                color: Colors.white,
              ),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                // Mark as read
                if (!notification.isRead) {
                  await _markAsRead(notification.id);
                }
                return false; // Don't dismiss
              } else {
                // Delete
                return true;
              }
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                _deleteNotification(notification.id);
              }
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: notification.isRead ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: notification.isRead ? Colors.white : Colors.blue.shade50,
              child: InkWell(
                onTap: () {
                  if (!notification.isRead) {
                    _markAsRead(notification.id);
                  }
                  _handleNotificationTap(notification);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNotificationIcon(notification),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: TextStyle(
                                      fontWeight: notification.isRead 
                                          ? FontWeight.normal 
                                          : FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (!notification.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: notification.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.content,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeago.format(notification.timestamp, locale: 'id'),
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                                if (notification.type == NotificationType.eventReminder) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.event,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Acara',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationItem notification) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: notification.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        notification.icon,
        color: notification.color,
        size: 20,
      ),
    );
  }

  void _handleNotificationTap(NotificationItem notification) {
    // Handle navigation based on notification type
    switch (notification.type) {
      case NotificationType.eventReminder:
        if (notification.eventId != null) {
          // Navigate to event detail
          // Navigator.pushNamed(context, '/event-detail', arguments: notification.eventId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigasi ke detail acara: ${notification.eventId}'),
            ),
          );
        }
        break;
      case NotificationType.comment:
      case NotificationType.share:
      case NotificationType.system:
      case NotificationType.summary:
        // Handle other notification types
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notifikasi: ${notification.title}'),
          ),
        );
        break;
    }
  }
}
