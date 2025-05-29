import 'package:flutter/material.dart';

enum NotificationType {
  eventReminder,
  comment,
  share,
  system,
  summary,
}

class NotificationItem {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;
  final String? eventId;
  final String? relatedId;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.isRead,
    required this.type,
    this.eventId,
    this.relatedId,
    this.data,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['is_read'] ?? false,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.system,
      ),
      eventId: json['event_id'],
      relatedId: json['related_id'],
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'type': type.toString().split('.').last,
      'event_id': eventId,
      'related_id': relatedId,
      'data': data,
    };
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    NotificationType? type,
    String? eventId,
    String? relatedId,
    Map<String, dynamic>? data,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      eventId: eventId ?? this.eventId,
      relatedId: relatedId ?? this.relatedId,
      data: data ?? this.data,
    );
  }

  // Helper method untuk mendapatkan icon berdasarkan type
  IconData get icon {
    switch (type) {
      case NotificationType.eventReminder:
        return Icons.alarm;
      case NotificationType.comment:
        return Icons.comment;
      case NotificationType.share:
        return Icons.share;
      case NotificationType.system:
        return Icons.info;
      case NotificationType.summary:
        return Icons.summarize;
    }
  }

  // Helper method untuk mendapatkan warna berdasarkan type
  Color get color {
    switch (type) {
      case NotificationType.eventReminder:
        return Colors.orange;
      case NotificationType.comment:
        return Colors.blue;
      case NotificationType.share:
        return Colors.green;
      case NotificationType.system:
        return Colors.red;
      case NotificationType.summary:
        return Colors.purple;
    }
  }
}
