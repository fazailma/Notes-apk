import 'package:flutter/material.dart';
import 'package:your_creative_notebook/models/folder.dart';

class FolderChip extends StatelessWidget {
  final Folder folder;
  final bool isSelected;

  const FolderChip({
    Key? key,
    required this.folder,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? folder.color : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: folder.color.withOpacity(isSelected ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isSelected ? Colors.transparent : folder.color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            folder.icon,
            size: 18,
            color: isSelected ? Colors.white : folder.color,
          ),
          const SizedBox(width: 6),
          Text(
            folder.name,
            style: TextStyle(
              color: isSelected ? Colors.white : folder.color.withOpacity(0.9),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
