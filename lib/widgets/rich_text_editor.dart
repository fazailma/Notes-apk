import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RichTextEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final TextStyle? style;

  const RichTextEditor({
    Key? key,
    required this.controller,
    required this.focusNode,
    this.hintText = '',
    this.style,
  }) : super(key: key);

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  
  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _focusNode = widget.focusNode;
    
    // Listen untuk perubahan teks
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      // Trigger rebuild untuk update formatting
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Background untuk menangkap tap
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _focusNode.requestFocus();
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          
          // Rich text display
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRichTextDisplay(),
                const SizedBox(height: 100), // Space untuk cursor
              ],
            ),
          ),
          
          // Invisible TextField untuk input
          Positioned.fill(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                color: Colors.transparent, // Buat invisible
                fontSize: 16,
                height: 1.5,
              ),
              cursorColor: Colors.blue,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichTextDisplay() {
    final text = _controller.text;
    
    if (text.isEmpty) {
      return Text(
        widget.hintText,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 16,
          height: 1.5,
        ),
      );
    }

    return _buildFormattedContent(text);
  }

  Widget _buildFormattedContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.startsWith('- [ ]') || line.startsWith('- [x]')) {
        widgets.add(_buildTodoLine(line, i));
      } else if (line.startsWith('• ')) {
        widgets.add(_buildBulletLine(line.substring(2).trim()));
      } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
        widgets.add(_buildNumberedLine(line));
      } else {
        widgets.add(_buildFormattedTextLine(line));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildTodoLine(String line, int lineIndex) {
    final isCompleted = line.startsWith('- [x]');
    final text = line.substring(5).trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
            color: isCompleted ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRichText(
              text,
              baseStyle: TextStyle(
                fontSize: 16,
                height: 1.5,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16, height: 1.5)),
          Expanded(
            child: _buildRichText(
              text,
              baseStyle: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedLine(String line) {
    final match = RegExp(r'^(\d+\.\s)(.*)$').firstMatch(line);
    if (match != null) {
      final number = match.group(1) ?? '';
      final text = match.group(2) ?? '';
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(number, style: const TextStyle(fontSize: 16, height: 1.5)),
            Expanded(
              child: _buildRichText(
                text,
                baseStyle: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: _buildRichText(
        line,
        baseStyle: const TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }

  Widget _buildFormattedTextLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: _buildRichText(
        text,
        baseStyle: const TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }

  Widget _buildRichText(String text, {required TextStyle baseStyle}) {
    if (text.isEmpty) {
      return Text('', style: baseStyle);
    }

    // Jika tidak ada format markdown, return teks biasa
    if (!text.contains('**') && !text.contains('*') && !text.contains('__')) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    while (currentIndex < text.length) {
      // Cari format bold (**text**)
      final boldMatch = RegExp(r'\*\*(.*?)\*\*').firstMatch(text.substring(currentIndex));
      
      // Cari format underline (__text__)
      final underlineMatch = RegExp(r'__(.*?)__').firstMatch(text.substring(currentIndex));
      
      // Cari format italic (*text*)
      final italicMatch = RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)').firstMatch(text.substring(currentIndex));

      // Tentukan match yang paling dekat
      int? nextMatchStart;
      RegExpMatch? nextMatch;
      String formatType = '';

      if (boldMatch != null) {
        nextMatchStart = currentIndex + boldMatch.start;
        nextMatch = boldMatch;
        formatType = 'bold';
      }

      if (underlineMatch != null) {
        final underlineStart = currentIndex + underlineMatch.start;
        if (nextMatchStart == null || underlineStart < nextMatchStart) {
          nextMatchStart = underlineStart;
          nextMatch = underlineMatch;
          formatType = 'underline';
        }
      }

      if (italicMatch != null) {
        final italicStart = currentIndex + italicMatch.start;
        if (nextMatchStart == null || italicStart < nextMatchStart) {
          nextMatchStart = italicStart;
          nextMatch = italicMatch;
          formatType = 'italic';
        }
      }

      if (nextMatch != null && nextMatchStart != null) {
        // Tambahkan teks sebelum format
        if (nextMatchStart > currentIndex) {
          final beforeText = text.substring(currentIndex, nextMatchStart);
          spans.add(TextSpan(text: beforeText, style: baseStyle));
        }

        // Tambahkan teks dengan format
        final formattedText = nextMatch.group(1) ?? '';
        TextStyle formattedStyle = baseStyle;

        switch (formatType) {
          case 'bold':
            formattedStyle = baseStyle.copyWith(fontWeight: FontWeight.bold);
            break;
          case 'italic':
            formattedStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
            break;
          case 'underline':
            formattedStyle = baseStyle.copyWith(decoration: TextDecoration.underline);
            break;
        }

        spans.add(TextSpan(text: formattedText, style: formattedStyle));

        // Update currentIndex
        currentIndex = nextMatchStart + nextMatch.end;
      } else {
        // Tidak ada format lagi, tambahkan sisa teks
        final remainingText = text.substring(currentIndex);
        spans.add(TextSpan(text: remainingText, style: baseStyle));
        break;
      }
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
