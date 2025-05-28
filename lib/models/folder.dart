import 'package:flutter/material.dart';

class Folder {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  int noteCount;

  Folder({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.noteCount = 0,
  });

  // Fungsi untuk mengonversi data PocketBase ke objek Folder
  factory Folder.fromPocketBase(Map<String, dynamic> json) {
    return Folder(
      id: json['id'],
      name: json['name'] ?? 'Unnamed Folder',
      color: _getColorFromString(json['color']),
      icon: _getIconFromString(json['icon']),
      noteCount: json['note_count'] ?? 0,
    );
  }

  // Backward compatibility
  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder.fromPocketBase(json);
  }

  // Helper method untuk menentukan warna berdasarkan string
  static Color _getColorFromString(String? colorString) {
    if (colorString == null) return Colors.grey;
    
    // Check if colorString is a hex code with #
    if (colorString.startsWith('#')) {
      try {
        final hexCode = colorString.replaceFirst('#', '');
        return Color(int.parse('0xFF$hexCode'));
      } catch (e) {
        print('Error parsing color hex: $e');
        return Colors.grey;
      }
    }
    
    // Otherwise check for named colors
    switch (colorString.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'yellow':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  // Helper method untuk menentukan ikon berdasarkan string
  static IconData _getIconFromString(String? iconString) {
    switch (iconString?.toLowerCase()) {
      case 'school':
        return Icons.school;
      case 'work':
        return Icons.work;
      case 'book':
        return Icons.book;
      case 'note':
        return Icons.note;
      case 'list':
        return Icons.list;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      default:
        return Icons.folder;
    }
  }
  
  // Method to convert Folder to PocketBase format
  Map<String, dynamic> toPocketBase() {
    return {
      'name': name,
      'color': _getColorName(color),
      'icon': _getIconName(icon),
      'note_count': noteCount,
    };
  }
  
  // Helper method to convert Color to string
  static String _getColorName(Color color) {
    if (color == Colors.blue) return 'blue';
    if (color == Colors.green) return 'green';
    if (color == Colors.red) return 'red';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.purple) return 'purple';
    if (color == Colors.yellow) return 'yellow';
    return 'grey';
  }
  
  // Helper method to convert IconData to string
  static String _getIconName(IconData icon) {
    if (icon == Icons.school) return 'school';
    if (icon == Icons.work) return 'work';
    if (icon == Icons.book) return 'book';
    if (icon == Icons.note) return 'note';
    if (icon == Icons.list) return 'list';
    if (icon == Icons.favorite) return 'favorite';
    if (icon == Icons.star) return 'star';
    return 'folder';
  }

  // Create a copy of the Folder with new values
  Folder copyWith({
    String? name,
    Color? color,
    IconData? icon,
    int? noteCount,
  }) {
    return Folder(
      id: this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      noteCount: noteCount ?? this.noteCount,
    );
  }

  @override
  String toString() {
    return 'Folder(id: $id, name: $name, noteCount: $noteCount)';
  }
}