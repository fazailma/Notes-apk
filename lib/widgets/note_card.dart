import 'package:flutter/material.dart';
import 'package:your_creative_notebook/models/note.dart';
import 'package:intl/intl.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteCard({
    Key? key,
    required this.note,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format date
    final DateFormat formatter = DateFormat('dd MMM yyyy');
    final String formattedDate = formatter.format(note.updatedAt);
    
    // Determine color based on note ID to ensure consistency
    final int colorIndex = note.id.hashCode % 4;
    final Color backgroundColor = _getNoteColor(colorIndex);
    final Color textColor = colorIndex == 3 ? Colors.white : Colors.black87;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.title.isNotEmpty ? note.title : 'Untitled Note',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                note.content,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  height: 1.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getNoteColor(int index) {
    // Return colors based on index to match the image
    switch (index % 4) {
      case 0:
        return Colors.yellow[100]!;
      case 1:
        return Colors.blue[100]!;
      case 2:
        return Colors.grey[300]!;
      case 3:
        return Colors.blue[400]!;
      default:
        return Colors.white;
    }
  }
}
