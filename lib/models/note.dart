import 'package:flutter/material.dart';

class Note {
  final String id;
  String title;
  String content;
  final DateTime createdAt;
  DateTime updatedAt;
  String? folderId;
  String? userId;
  Color color;
  List<String>? tags;

  Note({
    required this.id,
    this.title = '',
    this.content = '',
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.userId,
    this.color = Colors.white,
    this.tags,
  });

  // Factory constructor for creating a Note from PocketBase RecordModel
  factory Note.fromPocketBase(Map<String, dynamic> json) {
    // Debug the incoming data
    print('Creating Note from JSON: $json');
    
    // Handle dates properly - they could be DateTime objects or strings
    DateTime createdAt;
    DateTime updatedAt;
    
    if (json['created'] is String) {
      createdAt = DateTime.parse(json['created']);
    } else if (json['created'] is DateTime) {
      createdAt = json['created'];
    } else {
      createdAt = DateTime.now();
    }
    
    if (json['updated'] is String) {
      updatedAt = DateTime.parse(json['updated']);
    } else if (json['updated'] is DateTime) {
      updatedAt = json['updated'];
    } else {
      updatedAt = DateTime.now();
    }
    
    // Handle color
    Color noteColor = Colors.white;
    if (json['color'] != null) {
      noteColor = _getColorFromString(json['color']);
    } else {
      // Create a pseudo-random color based on the ID
      if (json['id'] != null) {
        final colorIndex = json['id'].hashCode % 6;
        switch (colorIndex) {
          case 0: noteColor = Colors.blue.shade50; break;
          case 1: noteColor = Colors.green.shade50; break;
          case 2: noteColor = Colors.orange.shade50; break;
          case 3: noteColor = Colors.red.shade50; break;
          case 4: noteColor = Colors.purple.shade50; break;
          case 5: noteColor = Colors.yellow.shade50; break;
        }
      }
    }
    
    // Parse tags if available
    List<String>? noteTags;
    if (json['tags'] != null) {
      if (json['tags'] is List) {
        noteTags = (json['tags'] as List).map((item) => item.toString()).toList();
      } else if (json['tags'] is String) {
        // Handle comma-separated string of tags
        noteTags = (json['tags'] as String).split(',').map((tag) => tag.trim()).toList();
      }
    }
    
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      folderId: json['folder_id'],
      userId: json['user_id'],
      color: noteColor,
      tags: noteTags,
    );
  }

  // For backward compatibility
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note.fromPocketBase(json);
  }

  // Convert Note to PocketBase format for creating/updating
  Map<String, dynamic> toPocketBase() {
    final data = {
      'title': title,
      'content': content,
      'user_id': userId,
    };
    
    // Only include folder_id if it's not null and not empty
    if (folderId != null && folderId!.isNotEmpty) {
      data['folder_id'] = folderId;
    }
    
    // Convert color to string
    if (color != Colors.white) {
      data['color'] = _getColorName(color);
    }
    
    // Include tags if available
    if (tags != null && tags!.isNotEmpty) {
      data['tags'] = tags?.join(',');  // Convert tags to comma-separated string
    }
    
    return data;
  }

  // Create a copy of the Note with new values
  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    String? folderId,
    String? userId,
    Color? color,
    List<String>? tags,
  }) {
    return Note(
      id: this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Default to current time for updates
      folderId: folderId ?? this.folderId,
      userId: userId ?? this.userId,
      color: color ?? this.color,
      tags: tags ?? this.tags,
    );
  }

  // Helper method for color
  static Color _getColorFromString(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'blue':
        return Colors.blue.shade50;
      case 'green':
        return Colors.green.shade50;
      case 'orange':
        return Colors.orange.shade50;
      case 'red':
        return Colors.red.shade50;
      case 'purple':
        return Colors.purple.shade50;
      case 'yellow':
        return Colors.yellow.shade50;
      default:
        // Try to parse hex color if it starts with #
        if (colorString.startsWith('#')) {
          try {
            final hexCode = colorString.replaceFirst('#', '');
            return Color(int.parse('0xFF$hexCode'));
          } catch (e) {
            print('Error parsing color hex: $e');
          }
        }
        return Colors.white;
    }
  }
  
  // Helper method to convert Color to string
  static String _getColorName(Color color) {
    if (color == Colors.blue.shade50) return 'blue';
    if (color == Colors.green.shade50) return 'green';
    if (color == Colors.orange.shade50) return 'orange';
    if (color == Colors.red.shade50) return 'red';
    if (color == Colors.purple.shade50) return 'purple';
    if (color == Colors.yellow.shade50) return 'yellow';
    return 'white';
  }
  
  @override
  String toString() {
    return 'Note(id: $id, title: $title, folderId: $folderId)';
  }
}
