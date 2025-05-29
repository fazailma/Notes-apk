import 'package:flutter/material.dart';

class Event {
  final String id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final bool allDay;
  final String? color;
  final String? location;
  final int? reminder;
  final String userId;
  final DateTime created;
  final DateTime updated;

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.allDay = false,
    this.color,
    this.location,
    this.reminder,
    required this.userId,
    required this.created,
    required this.updated,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      allDay: json['all_day'] ?? false,
      color: json['color'],
      location: json['location'],
      reminder: json['reminder'],
      userId: json['user_id'] ?? '',
      created: DateTime.parse(json['created']),
      updated: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'all_day': allDay,
      'color': color,
      'location': location,
      'reminder': reminder,
      'user_id': userId,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? allDay,
    String? color,
    String? location,
    int? reminder,
    String? userId,
    DateTime? created,
    DateTime? updated,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      allDay: allDay ?? this.allDay,
      color: color ?? this.color,
      location: location ?? this.location,
      reminder: reminder ?? this.reminder,
      userId: userId ?? this.userId,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  // Helper method untuk mendapatkan warna sebagai Color object
  Color get colorValue {
    if (color == null || color!.isEmpty) {
      return const Color(0xFF2196F3); // Default blue
    }
    
    try {
      // Jika color dalam format hex (contoh: "#FF5722" atau "FF5722")
      String colorString = color!.replaceAll('#', '');
      if (colorString.length == 6) {
        colorString = 'FF$colorString'; // Tambahkan alpha channel
      }
      return Color(int.parse(colorString, radix: 16));
    } catch (e) {
      // Jika parsing gagal, return default color
      return const Color(0xFF2196F3);
    }
  }

  // Helper method untuk format tanggal
  String get formattedDate {
    if (allDay) {
      if (startDate.day == endDate.day && 
          startDate.month == endDate.month && 
          startDate.year == endDate.year) {
        return '${startDate.day}/${startDate.month}/${startDate.year}';
      } else {
        return '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}';
      }
    } else {
      return '${startDate.day}/${startDate.month} ${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}';
    }
  }

  // Helper method untuk format waktu
  String get formattedTime {
    if (allDay) {
      return 'All Day';
    } else {
      final startTime = '${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}';
      final endTime = '${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}';
      return '$startTime - $endTime';
    }
  }
}