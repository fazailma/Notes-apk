import 'package:flutter/material.dart';
import 'package:your_creative_notebook/models/note.dart';
import 'package:intl/intl.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note note;
  final bool isNewNote;

  const NoteDetailScreen({
    super.key,
    required this.note,
    this.isNewNote = false,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _contentFocusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _contentFocusNode = FocusNode();
    _isEditing = widget.isNewNote;

    if (widget.isNewNote) {
      // Set focus to content for new notes after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_contentFocusNode);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  void _saveNote() {
    if (_titleController.text.isEmpty) {
      _titleController.text = 'Untitled Note';
    }

    // Buat salinan baru dari objek note dengan data yang diperbarui
    final updatedNote = widget.note.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );

    // Kembalikan updatedNote ke NotesScreen
    Navigator.pop(context, updatedNote);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        FocusScope.of(context).requestFocus(_contentFocusNode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Jika dalam mode edit, simpan catatan terlebih dahulu
            if (_isEditing) {
              _saveNote();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _isEditing
            ? TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'Note Title',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
              )
            : Text(widget.note.title.isEmpty ? 'Untitled Note' : widget.note.title),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: () {
                _saveNote();
                setState(() {
                  _isEditing = false;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: _toggleEditMode,
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Date: ${_formatDate(widget.note.updatedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                if (!_isEditing)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    onPressed: _toggleEditMode,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save'),
                    onPressed: () {
                      _saveNote();
                      setState(() {
                        _isEditing = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isEditing
                ? _buildEditableContent()
                : _buildReadOnlyContent(),
          ),
          if (_isEditing) _buildEditingToolbar(),
        ],
      ),
      floatingActionButton: _isEditing ? FloatingActionButton(
        onPressed: () {
          _saveNote();
          setState(() {
            _isEditing = false;
          });
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.save),
      ) : FloatingActionButton(
        onPressed: _toggleEditMode,
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildEditableContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocusNode,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
        decoration: const InputDecoration(
          hintText: 'Start writing...',
          border: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }

  Widget _buildReadOnlyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        widget.note.content,
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildEditingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(30),
      ),
      margin: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.format_bold, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.format_italic, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.format_underline, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.format_list_bulleted, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.format_list_numbered, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.check_box, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}