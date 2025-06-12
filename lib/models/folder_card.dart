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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: folder.color.withOpacity(0.2), // Warna folder dengan opacity
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indikator warna kecil
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: folder.color,
                shape: BoxShape.circle,
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
            Text(
              '${folder.noteCount} notes',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
