import 'package:flutter/material.dart';
import 'package:your_creative_notebook/models/folder.dart';

class FolderCard extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;

  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine color based on folder ID to ensure consistency
    final int colorIndex = folder.id.hashCode % 4;
    final Color backgroundColor = _getFolderColor(colorIndex);
    
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
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: folder.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: folder.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(
              folder.name,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFolderColor(int index) {
    // Return pastel colors based on index
    switch (index % 4) {
      case 0:
        return Colors.yellow[100]!;
      case 1:
        return Colors.pink[50]!;
      case 2:
        return Colors.blue[100]!;
      case 3:
        return Colors.green[100]!;
      default:
        return Colors.grey[100]!;
    }
  }
}
