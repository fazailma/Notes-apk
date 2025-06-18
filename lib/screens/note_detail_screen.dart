import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:your_creative_notebook/models/note.dart';
import 'package:your_creative_notebook/services/pocketbase_service.dart';
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
  late quill.QuillController _quillController;
  late FocusNode _contentFocusNode;
  late ScrollController _scrollController;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _hasNavigatedBack = false;
  final PocketbaseService _pbService = PocketbaseService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentFocusNode = FocusNode();
    _scrollController = ScrollController();

    // Initialize QuillController with content
    try {
      final contentJson = widget.note.content.isNotEmpty
          ? jsonDecode(widget.note.content)
          : <dynamic>[];
      _quillController = quill.QuillController(
        document: quill.Document.fromJson(contentJson),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      print('Error parsing note content: $e');
      _quillController = quill.QuillController(
        document: quill.Document(),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    _isEditing = widget.isNewNote;

    // Add listeners to track changes
    _titleController.addListener(_onContentChanged);
    _quillController.addListener(_onContentChanged);

    if (widget.isNewNote) {
      _hasUnsavedChanges = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_contentFocusNode);
      });
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onContentChanged);
    _quillController.removeListener(_onContentChanged);
    _titleController.dispose();
    _quillController.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges =
            _titleController.text.trim() != widget.note.title ||
                jsonEncode(_quillController.document.toDelta().toJson()) !=
                    (widget.note.content.isEmpty ? '[]' : widget.note.content);
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _saveNote() async {
    if (_isSaving || _hasNavigatedBack) {
      print('Save already in progress or already navigated back, ignoring...');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String title = _titleController.text.trim();
      if (title.isEmpty) {
        title = 'Untitled Note';
        _titleController.text = title;
      }

      String content = jsonEncode(_quillController.document.toDelta().toJson());

      print('Starting save process...');

      if (widget.isNewNote) {
        print('Creating new note with title: "$title"');
        print('Content length: ${content.length} characters');
        print('Folder ID: ${widget.note.folderId ?? "None"}');

        final createdNote = await _pbService.createNote(
          title,
          content,
          folderId: widget.note.folderId,
        );

        print('Note created successfully with ID: ${createdNote.id}');

        final updatedNote = Note(
          id: createdNote.id,
          title: title,
          content: content,
          createdAt: DateTime.parse(createdNote.created),
          updatedAt: DateTime.parse(createdNote.updated),
          folderId: widget.note.folderId,
          userId: widget.note.userId,
          color: widget.note.color,
          tags: widget.note.tags,
        );

        if (mounted && !_hasNavigatedBack) {
          _hasNavigatedBack = true;
          print('Navigating back with created note...');
          Navigator.pop(context, updatedNote);
        }
      } else {
        print('Updating existing note with ID: ${widget.note.id}');

        await _pbService.updateNote(
          widget.note.id,
          title,
          content,
        );

        print('Note updated successfully');

        final updatedNote = widget.note.copyWith(
          title: title,
          content: content,
          updatedAt: DateTime.now(),
        );

        if (mounted && !_hasNavigatedBack) {
          _hasNavigatedBack = true;
          print('Navigating back with updated note...');
          Navigator.pop(context, updatedNote);
        }
      }
    } catch (e) {
      print('Error saving note: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        FocusScope.of(context).requestFocus(_contentFocusNode);
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (_isSaving || _hasNavigatedBack) {
      return false;
    }

    if (_isEditing && _hasUnsavedChanges) {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.save, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Save Changes',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ],
          ),
          content: const Text(
            'Do you want to save your changes before leaving?',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Discard',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ],
        ),
      );

      if (shouldSave == true) {
        await _saveNote();
        return false;
      } else if (shouldSave == false) {
        if (!_hasNavigatedBack) {
          _hasNavigatedBack = true;
          Navigator.pop(context);
        }
        return false;
      }
      return false;
    } else if (!_hasNavigatedBack) {
      _hasNavigatedBack = true;
      Navigator.pop(context);
      return false;
    }

    return false;
  }

  void _handleBackPress() {
    if (_isSaving || _hasNavigatedBack) {
      return;
    }
    _onWillPop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _onWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: widget.note.color,
        appBar: AppBar(
          backgroundColor: widget.note.color,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.purple,
                size: 20,
              ),
              onPressed: _isSaving ? null : _handleBackPress,
            ),
          ),
          title: _isEditing
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Note Title',
                      hintStyle: TextStyle(fontFamily: 'Poppins'),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                )
              : Text(
                  widget.note.title.isEmpty
                      ? 'Untitled Note'
                      : widget.note.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.black87,
                  ),
                ),
          actions: [
            if (_isEditing && _hasUnsavedChanges)
              _isSaving
                  ? Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 24,
                      height: 24,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.purple,
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.save),
                        color: Colors.green,
                        tooltip: 'Save',
                        onPressed: _saveNote,
                      ),
                    )
            else if (!_isEditing)
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit),
                  color: Colors.purple,
                  tooltip: 'Edit',
                  onPressed: _toggleEditMode,
                ),
              ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.more_vert),
                color: Colors.grey[600],
                onPressed: () {},
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last edited: ${_formatDate(widget.note.updatedAt)}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (_isSaving)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Saving...',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_hasUnsavedChanges && _isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            size: 12,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Unsaved',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!_isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Saved',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
      ),
    );
  }

  Widget _buildEditableContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: quill.QuillEditor(
        configurations: quill.QuillEditorConfigurations(
          controller: _quillController,
          placeholder: 'Start writing your note...',
          padding: EdgeInsets.zero,
          autoFocus: widget.isNewNote,
          expands: true,
        ),
        focusNode: _contentFocusNode,
        scrollController: _scrollController,
      ),
    );
  }

  Widget _buildReadOnlyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      controller: _scrollController,
      child: AbsorbPointer(
        absorbing: true, // Ini akan membuat editor tidak bisa diedit
        child: quill.QuillEditor(
          configurations: quill.QuillEditorConfigurations(
            controller: _quillController,
            placeholder: 'This note is empty.',
            padding: EdgeInsets.zero,
            autoFocus: false,
            expands: false,
          ),
          focusNode: FocusNode(),
          scrollController: ScrollController(),
        ),
      ),
    );
  }

  // Fungsi untuk mengecek apakah format tertentu sedang aktif
  bool _isFormatActive(quill.Attribute attribute) {
    final currentStyle = _quillController.getSelectionStyle().attributes;
    return currentStyle[attribute.key] != null;
  }

  // Fungsi untuk mengecek apakah list tertentu sedang aktif
  bool _isListActive(quill.Attribute attribute) {
    final currentStyle = _quillController.getSelectionStyle().attributes;
    final currentListType = currentStyle['list'];
    return currentListType == attribute.value;
  }

  Widget _buildEditingToolbar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple[100]!,
            Colors.purple[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.purple.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildToolbarButton(
              Icons.format_bold,
              'Bold',
              () => _toggleFormat(quill.Attribute.bold),
              isActive: _isFormatActive(quill.Attribute.bold),
            ),
            const SizedBox(width: 4),
            _buildToolbarButton(
              Icons.format_italic,
              'Italic',
              () => _toggleFormat(quill.Attribute.italic),
              isActive: _isFormatActive(quill.Attribute.italic),
            ),
            const SizedBox(width: 4),
            _buildToolbarButton(
              Icons.format_underline,
              'Underline',
              () => _toggleFormat(quill.Attribute.underline),
              isActive: _isFormatActive(quill.Attribute.underline),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 24,
              color: Colors.purple.withOpacity(0.3),
            ),
            const SizedBox(width: 8),
            _buildToolbarButton(
              Icons.format_list_bulleted,
              'Bullet List',
              () => _toggleList(quill.Attribute.ul),
              isActive: _isListActive(quill.Attribute.ul),
            ),
            const SizedBox(width: 4),
            _buildToolbarButton(
              Icons.format_list_numbered,
              'Numbered List',
              () => _toggleList(quill.Attribute.ol),
              isActive: _isListActive(quill.Attribute.ol),
            ),
            const SizedBox(width: 4),
            _buildToolbarButton(
              Icons.checklist,
              'Checklist',
              () => _toggleList(quill.Attribute.unchecked),
              isActive: _isListActive(quill.Attribute.unchecked),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton(
    IconData icon, 
    String tooltip, 
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive 
                  ? Colors.purple.withOpacity(0.8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive 
                  ? Border.all(color: Colors.purple, width: 1.5)
                  : null,
              boxShadow: isActive 
                  ? [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive 
                  ? Colors.white 
                  : Colors.purple[700],
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _toggleFormat(quill.Attribute attribute) {
    final currentStyle = _quillController.getSelectionStyle().attributes;
    if (currentStyle[attribute.key] != null) {
      _quillController.formatSelection(quill.Attribute.clone(attribute, null));
    } else {
      _quillController.formatSelection(attribute);
    }
    // Trigger rebuild untuk update visual feedback
    setState(() {});
  }

  void _toggleList(quill.Attribute attribute) {
    final currentStyle = _quillController.getSelectionStyle().attributes;
    final currentListType = currentStyle['list'];

    if (currentListType == attribute.value) {
      _quillController.formatSelection(quill.Attribute.clone(attribute, null));
    } else {
      _quillController.formatSelection(attribute);
    }
    // Trigger rebuild untuk update visual feedback
    setState(() {});
  }
}