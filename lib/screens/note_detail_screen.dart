import 'package:flutter/material.dart';
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
  late TextEditingController _contentController;
  late FocusNode _contentFocusNode;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _hasNavigatedBack = false; // Flag to prevent multiple navigation
  final PocketbaseService _pbService = PocketbaseService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _contentFocusNode = FocusNode();
    _isEditing = widget.isNewNote;

    // Add listeners to track changes
    _titleController.addListener(_onContentChanged);
    _contentController.addListener(_onContentChanged);

    if (widget.isNewNote) {
      _hasUnsavedChanges = true; // New notes always have unsaved changes
      // Set focus to content for new notes after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_contentFocusNode);
      });
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onContentChanged);
    _contentController.removeListener(_onContentChanged);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = _titleController.text.trim() != widget.note.title ||
                           _contentController.text.trim() != widget.note.content;
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  // This is the ONLY method that should save notes
  Future<void> _saveNote() async {
    // Prevent multiple saves or navigation
    if (_isSaving || _hasNavigatedBack) {
      print('Save already in progress or already navigated back, ignoring...');
      return;
    }
    
    setState(() {
      _isSaving = true;
    });

    try {
      // Set default title if empty
      String title = _titleController.text.trim();
      if (title.isEmpty) {
        title = 'Untitled Note';
        _titleController.text = title;
      }

      String content = _contentController.text.trim();
      
      print('Starting save process...');

      if (widget.isNewNote) {
        // For new notes, create in database
        print('Creating new note with title: "$title"');
        print('Content length: ${content.length} characters');
        print('Folder ID: ${widget.note.folderId ?? "None"}');
        
        final createdNote = await _pbService.createNote(
          title,
          content,
          folderId: widget.note.folderId,
        );
        
        print('Note created successfully with ID: ${createdNote.id}');
        
        // Create updated note object with the new ID
        final updatedNote = Note(
          id: createdNote.id,
          title: title,
          content: content,
          createdAt: DateTime.parse(createdNote.created),
          updatedAt: DateTime.parse(createdNote.updated),
          folderId: widget.note.folderId,
          userId: widget.note.userId,
        );

        // Return the created note and prevent multiple navigation
        if (mounted && !_hasNavigatedBack) {
          _hasNavigatedBack = true;
          print('Navigating back with created note...');
          Navigator.pop(context, updatedNote);
        }
      } else {
        // For existing notes, update in database
        print('Updating existing note with ID: ${widget.note.id}');
        
        await _pbService.updateNote(
          widget.note.id,
          title,
          content,
        );
        
        print('Note updated successfully');
        
        // Create updated note object
        final updatedNote = widget.note.copyWith(
          title: title,
          content: content,
          updatedAt: DateTime.now(),
        );

        // Return the updated note and prevent multiple navigation
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
    // This handles Android back button
    if (_isSaving || _hasNavigatedBack) {
      return false; // Don't allow back navigation if saving or already navigated
    }

    if (_isEditing && _hasUnsavedChanges) {
      // Show dialog asking if user wants to save
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
                child: Icon(Icons.save, color: Colors.orange, size: 24),
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
        return false; // Navigation is handled in _saveNote
      } else if (shouldSave == false) {
        // Discard changes and allow back navigation
        if (!_hasNavigatedBack) {
          _hasNavigatedBack = true;
          Navigator.pop(context); // Pop without result
        }
        return false;
      }
      return false; // Dialog dismissed, don't navigate back
    } else if (!_hasNavigatedBack) {
      _hasNavigatedBack = true;
      Navigator.pop(context); // Pop without result
      return false;
    }
    
    return false; // Default: don't allow system back navigation
  }

  void _handleBackPress() {
    if (_isSaving || _hasNavigatedBack) {
      return; // Don't do anything if saving or already navigated
    }

    _onWillPop(); // Use the same logic as the Android back button
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                )
              : Text(
                  widget.note.title.isEmpty ? 'Untitled Note' : widget.note.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.black87,
                  ),
                ),
          actions: [
            // ONLY show save button in header when editing and has changes
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
            // Status bar
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
                  // Status indicator
                  if (_isSaving)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            
            // Content area
            Expanded(
              child: _isEditing
                  ? _buildEditableContent()
                  : _buildReadOnlyContent(),
            ),
            
            // Editing toolbar (only when editing)
            if (_isEditing) _buildEditingToolbar(),
          ],
        ),
        // NO FLOATING ACTION BUTTON - removed redundant save button
      ),
    );
  }

  Widget _buildEditableContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocusNode,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: 'Start writing your note...',
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.grey[500],
          ),
          border: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }

  Widget _buildReadOnlyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(
        widget.note.content.isEmpty ? 'This note is empty.' : widget.note.content,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          height: 1.6,
          color: widget.note.content.isEmpty ? Colors.grey[500] : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildEditingToolbar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolbarButton(Icons.format_bold, 'Bold'),
          _buildToolbarButton(Icons.format_italic, 'Italic'),
          _buildToolbarButton(Icons.format_underline, 'Underline'),
          _buildToolbarButton(Icons.format_list_bulleted, 'Bullet List'),
          _buildToolbarButton(Icons.format_list_numbered, 'Number List'),
          _buildToolbarButton(Icons.check_box, 'Checkbox'),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          // TODO: Implement formatting functionality
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
