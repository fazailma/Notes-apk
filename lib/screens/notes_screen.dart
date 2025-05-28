import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:your_creative_notebook/models/note.dart';
import 'package:your_creative_notebook/screens/note_detail_screen.dart';
import 'package:your_creative_notebook/services/pocketbase_service.dart';

class NotesScreen extends StatefulWidget {
  final String? folderId;

  const NotesScreen({super.key, this.folderId});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final PocketbaseService _pbService = PocketbaseService();
  List<Note> _notes = [];
  bool _isLoading = true;
  String? _folderName;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    if (widget.folderId != null) {
      _loadFolderName();
    }
  }

  // Load folder name for the app bar title
  Future<void> _loadFolderName() async {
    if (widget.folderId == null) return;

    try {
      final folders = await _pbService.getFolders();
      final folder = folders.firstWhere(
        (f) => f.id == widget.folderId,
        orElse: () => throw Exception('Folder not found'),
      );

      setState(() {
        _folderName = folder.data['name'];
      });
    } catch (e) {
      print('Error loading folder name: $e');
      // Jika terjadi error, tetapkan nama folder sebagai 'Unknown'
      setState(() {
        _folderName = 'Unknown';
      });
    }
  }

  // Load notes from PocketBase
  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if user is logged in
      if (!_pbService.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anda harus login terlebih dahulu')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get notes using PocketBase service
      List<RecordModel> noteRecords;
      if (widget.folderId != null) {
        print('Loading notes for folder ID: ${widget.folderId}');
        noteRecords = await _pbService.getNotesByFolder(widget.folderId!);
      } else {
        print('Loading all notes');
        noteRecords = await _pbService.getNotes();
      }

      print('Loaded ${noteRecords.length} notes');

      // Convert RecordModel to Note objects
      setState(() {
        _notes = noteRecords
            .map((record) => Note(
                  id: record.id,
                  title: record.data['title'] ?? '',
                  content: record.data['content'] ?? '',
                  createdAt: DateTime.parse(record.created),
                  updatedAt: DateTime.parse(record.updated),
                  folderId: record.data['folder_id'],
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat catatan: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add new note
  void _addNewNote() async {
    if (!_pbService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login terlebih dahulu')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          note: Note(
            id: '', // ID will be assigned by PocketBase
            title: '',
            content: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            folderId: widget.folderId,
          ),
          isNewNote: true,
        ),
      ),
    );

    if (result != null && result is Note) {
      try {
        // Create the note in PocketBase
        print('Creating note with title: ${result.title}');
        print('Note folder ID: ${result.folderId}');

        await _pbService.createNote(
          result.title,
          result.content,
          folderId: result.folderId,
        );
        // Reload notes to get the new note with the correct ID
        _loadNotes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan berhasil disimpan')),
        );
      } catch (e) {
        print('Error creating note: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan catatan: ${e.toString()}')),
        );
      }
    }
  }

  // Edit note
  void _editNote(Note note) async {
    if (!_pbService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login terlebih dahulu')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          note: note,
          isNewNote: false,
        ),
      ),
    );

    if (result != null && result is Note) {
      try {
        // Update the note in PocketBase
        await _pbService.updateNote(note.id, result.title, result.content);
        // Update the note in the local list
        setState(() {
          final index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) {
            _notes[index] = result;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan berhasil diperbarui')),
        );
      } catch (e) {
        print('Error updating note: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui catatan: ${e.toString()}')),
        );
      }
    }
  }

  // Delete note
  void _deleteNote(String id) async {
    if (!_pbService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login terlebih dahulu')),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: const Text('Apakah Anda yakin ingin menghapus catatan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete the note from PocketBase
        await _pbService.deleteNote(id);
        // Remove the note from the local list
        setState(() {
          _notes.removeWhere((note) => note.id == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan berhasil dihapus')),
        );
      } catch (e) {
        print('Error deleting note: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus catatan: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_folderName != null ? 'Catatan: $_folderName' : 'Catatan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotes,
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Belum ada catatan'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addNewNote,
                        child: const Text('Buat Catatan Baru'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text(
                          note.title.isNotEmpty
                              ? note.title
                              : 'Catatan Tanpa Judul',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteNote(note.id),
                        ),
                        onTap: () => _editNote(note),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewNote,
        tooltip: 'Tambah Catatan',
        child: const Icon(Icons.add),
      ),
    );
  }
}