import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

class Event {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final bool allDay;
  final String? colorHex; // Simpan sebagai string hex (misalnya '#1565C0')
  final String? location;
  final int? reminder;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.allDay = false,
    this.colorHex,
    this.location,
    this.reminder,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Konversi colorHex ke Color, dengan fallback ke Colors.blue jika gagal
  Color get color {
    if (colorHex == null) return Colors.blue;
    try {
      final hexCode = colorHex!.replaceFirst('#', '');
      return Color(int.parse('0xFF$hexCode'));
    } catch (e) {
      print('Error parsing color $colorHex: $e');
      return Colors.blue;
    }
  }

  bool isOnDay(DateTime day) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final target = DateTime(day.year, day.month, day.day);
    return !start.isAfter(target) && !end.isBefore(target);
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? allDay,
    String? colorHex,
    String? location,
    int? reminder,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      allDay: allDay ?? this.allDay,
      colorHex: colorHex ?? this.colorHex,
      location: location ?? this.location,
      reminder: reminder ?? this.reminder,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedStartTime => !allDay ? '${startDate.hour}:${startDate.minute.toString().padLeft(2, '0')}' : '';
  String get formattedEndTime => !allDay ? '${endDate.hour}:${endDate.minute.toString().padLeft(2, '0')}' : '';

  // Konversi Event ke Map untuk disimpan ke PocketBase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'all_day': allDay,
      'color': colorHex,
      'location': location,
      'reminder': reminder,
      'user_id': userId,
      'created': createdAt.toIso8601String(),
      'updated': updatedAt.toIso8601String(),
    };
  }

  // Factory untuk membuat Event dari RecordModel PocketBase
  factory Event.fromRecord(RecordModel record) {
    return Event(
      id: record.id,
      title: record.data['title'] ?? '',
      description: record.data['description'],
      startDate: DateTime.parse(record.data['start_date']),
      endDate: DateTime.parse(record.data['end_date']),
      allDay: record.data['all_day'] ?? false,
      colorHex: record.data['color'],
      location: record.data['location'],
      reminder: record.data['reminder'] as int?,
      userId: record.data['user_id'],
      createdAt: DateTime.parse(record.created),
      updatedAt: DateTime.parse(record.updated),
    );
  }
}