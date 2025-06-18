import 'package:flutter/material.dart';
import 'package:your_creative_notebook/models/note.dart';
import 'package:your_creative_notebook/models/folder.dart';
import 'package:your_creative_notebook/services/pocketbase_service.dart';
import 'package:your_creative_notebook/screens/note_detail_screen.dart';
import 'package:your_creative_notebook/widgets/note_card.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class NotesScreen extends StatefulWidget {
  final String? folderId;
  final String? searchQuery;
  final bool shouldCreateNewNote;

  const NotesScreen({
    super.key,
    this.folderId,
    this.searchQuery,
    this.shouldCreateNewNote = false,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final PocketbaseService _pbService = PocketbaseService();
  List<Note> _notes = [];
  bool _isLoading = true;
  String _folderName = '';
  Color _folderColor = Colors.purple;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    if (widget.searchQuery != null) {
      _searchController.text = widget.searchQuery!;
    }
    
    // Auto-create note if flag is set
    if (widget.shouldCreateNewNote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _createNewNote();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<dynamic> noteRecords;
      
      if (widget.folderId != null) {
        // Load notes from specific folder
        noteRecords = await _pbService.getNotesByFolder(widget.folderId!);
        
        // Get folder info - Fixed the error here
        final folderRecords = await _pbService.getFolders();
        final folderRecord = folderRecords.where(
          (folder) => folder.id == widget.folderId,
        ).firstOrNull;
        
        if (folderRecord != null) {
          _folderName = folderRecord.data['name'] ?? 'Unknown Folder';
          try {
            final colorStr = folderRecord.data['color'] ?? '#9C27B0';
            final hexCode = colorStr.replaceFirst('#', '');
            _folderColor = Color(int.parse('0xFF$hexCode'));
          } catch (e) {
            _folderColor = Colors.purple;
          }
        } else {
          _folderName = 'Unknown Folder';
          _folderColor = Colors.purple;
        }
      } else {
        // Load all notes
        noteRecords = await _pbService.getNotes();
        _folderName = 'All Notes';
      }

      // Convert to Note objects
      List<Note> notes = [];
      for (var record in noteRecords) {
        notes.add(Note(
          id: record.id,
          title: record.data['title'] ?? '',
          content: record.data['content'] ?? '',
          createdAt: DateTime.parse(record.created),
          updatedAt: DateTime.parse(record.updated),
          folderId: record.data['folder_id'],
          userId: record.data['user_id'],
        ));
      }

      // Filter by search query if provided
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        notes = notes.where((note) {
          final title = note.title.toLowerCase();
          final content = note.content.toLowerCase();
          final query = widget.searchQuery!.toLowerCase();
          return title.contains(query) || content.contains(query);
        }).toList();
      }

      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notes: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load notes: $e')),
      );
    }
  }

  void _navigateToNoteDetail(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    ).then((result) {
      // Check if note was updated and reload
      if (result != null) {
        print('Note detail returned with result, reloading notes...');
        _loadNotes();
      } else {
        // Still reload to catch any changes
        _loadNotes();
      }
    });
  }

  void _createNewNote() {
    if (!_pbService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create notes')),
      );
      return;
    }

    final newNote = Note(
      id: '',
      title: '',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folderId: widget.folderId,
      userId: _pbService.currentUser.id,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          note: newNote,
          isNewNote: true,
        ),
      ),
    ).then((result) async {
      print('Note detail returned with result: $result');
      
      // Only reload data if we got a result back
      if (result != null) {
        print('Reloading notes after creation/edit');
        await _loadNotes();
      }
    });
  }

  void _showNoteOptionsMenu(BuildContext context, Note note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Note info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _folderColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.note,
                      color: _folderColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title.isNotEmpty ? note.title : 'Untitled Note',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatDate(note.updatedAt),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Options
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete,
                    color: Colors.red[600],
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Delete Note',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                subtitle: Text(
                  'Remove this note permanently',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.grey[600],
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteNoteDialog(note);
                },
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showDeleteNoteDialog(Note note) {
    showDialog(
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
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Note',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to delete "${note.title.isNotEmpty ? note.title : 'Untitled Note'}"?',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _pbService.deleteNote(note.id);
                Navigator.pop(context);
                await _loadNotes(); // Reload data
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                print('Error deleting note: $e');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete note: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.purple,
                      ),
                    )
                  : _buildNotesContent(),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _folderColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _createNewNote,
          backgroundColor: _folderColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: _folderColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: _folderColor,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Centered folder title
          Expanded(
            child: Center(
              child: Text(
                _folderName,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          
          // Notes count badge (where refresh button was)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _folderColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_notes.length} notes',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _folderColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesContent() {
    if (_notes.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return _buildNoteCard(note, index);
        },
      ),
    );
  }

  // Fungsi untuk mengekstrak teks biasa dari konten Quill JSON
  String _extractPlainTextFromQuillContent(String jsonContent) {
    if (jsonContent.isEmpty) {
      return '';
    }

    try {
      // Parse JSON content
      final contentJson = jsonDecode(jsonContent);
      
      // Buat dokumen Quill dari JSON
      final document = quill.Document.fromJson(contentJson);
      
      // Ekstrak teks biasa
      return document.toPlainText();
    } catch (e) {
      print('Error extracting plain text from Quill content: $e');
      return '';
    }
  }

  Widget _buildNoteCard(Note note, int index) {
    final Color backgroundColor = _getNoteColor(index);
    final Color textColor = _getTextColor(backgroundColor);
    
    // Ekstrak teks biasa dari konten Quill
    final plainTextContent = _extractPlainTextFromQuillContent(note.content);

    return GestureDetector(
      onTap: () => _navigateToNoteDetail(note),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor,
              backgroundColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Note content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note icon only (removed date from here)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.note,
                        size: 16,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    // Removed date from here to avoid overlap with menu
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Note title
                Text(
                  note.title.isNotEmpty ? note.title : 'Untitled Note',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                // Date moved here (below title)
                Text(
                  _formatDate(note.updatedAt),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: textColor.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Note content - Menggunakan teks biasa yang diekstrak
                Expanded(
                  child: Text(
                    plainTextContent,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: textColor.withOpacity(0.8),
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 5, // Reduced to accommodate date
                  ),
                ),
              ],
            ),
            
            // Three-dot menu button
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showNoteOptionsMenu(context, note),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Empty state illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _folderColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.note_add,
              size: 60,
              color: _folderColor.withOpacity(0.6),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Empty state text
          Text(
            'No notes yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Tap the + button to create your first note',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Decorative elements
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDecorativeDot(_folderColor.withOpacity(0.3)),
              const SizedBox(width: 8),
              _buildDecorativeDot(_folderColor.withOpacity(0.5)),
              const SizedBox(width: 8),
              _buildDecorativeDot(_folderColor.withOpacity(0.7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getNoteColor(int index) {
    final colors = [
      Colors.purple[50]!,
      Colors.blue[50]!,
      Colors.green[50]!,
      Colors.orange[50]!,
      Colors.pink[50]!,
      Colors.yellow[50]!,
      Colors.indigo[50]!,
      Colors.teal[50]!,
    ];
    return colors[index % colors.length];
  }

  Color _getTextColor(Color backgroundColor) {
    // Calculate luminance to determine if we need dark or light text
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}

// Extension to add firstOrNull method if not available
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}