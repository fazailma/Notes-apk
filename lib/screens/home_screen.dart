import 'package:flutter/material.dart';
import 'package:your_creative_notebook/models/folder.dart';
import 'package:your_creative_notebook/models/note.dart';
import 'package:your_creative_notebook/services/pocketbase_service.dart';
import 'package:your_creative_notebook/screens/note_detail_screen.dart';
import 'package:your_creative_notebook/screens/notes_screen.dart';
import 'package:your_creative_notebook/screens/profile_screen.dart';
import 'package:your_creative_notebook/screens/calendar_screen.dart';
import 'package:your_creative_notebook/screens/notifications_screen.dart';
import 'package:your_creative_notebook/services/event_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PocketbaseService _pbService = PocketbaseService();
  List<Folder> _folders = [];
  List<Note> _recentNotes = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Note> _searchResults = [];
  bool _isSearchLoading = false;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
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

  Future<void> _initService() async {
    try {
      await _pbService.init();
      await _loadData();
    } catch (e) {
      print('Error initializing service: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing service: $e')),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!_pbService.isLoggedIn) {
        print('User is not logged in, showing login message');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anda harus login terlebih dahulu')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('Loading data for user ID: ${_pbService.currentUser.id}');
      print('Fetching folders');
      final folderRecords = await _pbService.getFolders();
      print('Fetched ${folderRecords.length} folders');

      List<Folder> folders = [];
      for (var record in folderRecords) {
        Color folderColor = Colors.purple;
        try {
          final colorStr = record.data['color'] ?? '#9C27B0';
          final hexCode = colorStr.replaceFirst('#', '');
          folderColor = Color(int.parse('0xFF$hexCode'));
        } catch (e) {
          print('Error parsing color: $e');
        }

        IconData folderIcon = Icons.folder;
        try {
          final iconStr = record.data['icon'] ?? 'folder';
          if (iconStr == 'note')
            folderIcon = Icons.note;
          else if (iconStr == 'work')
            folderIcon = Icons.work;
          else if (iconStr == 'favorite')
            folderIcon = Icons.favorite;
          else if (iconStr == 'star') folderIcon = Icons.star;
        } catch (e) {
          print('Error parsing icon: $e');
        }

        folders.add(Folder(
          id: record.id,
          name: record.data['name'] ?? 'Unnamed Folder',
          color: folderColor,
          icon: folderIcon,
          noteCount: 0,
        ));
      }

      print('Fetching recent notes');
      final recentNoteRecords = await _pbService.getRecentNotes(limit: 4);
      print('Fetched ${recentNoteRecords.length} recent notes');

      List<Note> recentNotes = [];
      for (var record in recentNoteRecords) {
        recentNotes.add(Note(
          id: record.id,
          title: record.data['title'] ?? '',
          content: record.data['content'] ?? '',
          createdAt: DateTime.parse(record.created),
          updatedAt: DateTime.parse(record.updated),
          folderId: record.data['folder_id'],
          userId: record.data['user_id'],
        ));
      }

      if (folders.isNotEmpty) {
        for (int i = 0; i < folders.length; i++) {
          try {
            final notesInFolder =
                await _pbService.getNotesByFolder(folders[i].id);
            folders[i] = folders[i].copyWith(noteCount: notesInFolder.length);
          } catch (e) {
            print('Error counting notes for folder ${folders[i].id}: $e');
          }
        }
      }

      setState(() {
        _folders = folders;
        _recentNotes = recentNotes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectFolder(String folderId, String folderName) {
    print('Selected folder ID: $folderId, Name: $folderName');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotesScreen(folderId: folderId),
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _navigateToNoteDetail(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    ).then((_) => _loadData());
  }

  void _createNewNote() {
    if (!_pbService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login terlebih dahulu')),
      );
      return;
    }
    _showSelectFolderDialog();
  }

  void _showSelectFolderDialog() {
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
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.create_new_folder,
                color: Colors.purple,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Choose Folder',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _folders.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No folders available',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a folder first to organize your notes',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _folders.length,
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: folder.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: folder.color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: folder.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            folder.icon,
                            color: folder.color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          folder.name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${folder.noteCount} notes',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context, folder);
                        },
                      ),
                    );
                  },
                ),
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
          if (_folders.isEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showCreateFolderDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
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
                'Create Folder',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    ).then((selectedFolder) {
      if (selectedFolder != null && selectedFolder is Folder) {
        print('Selected folder: ${selectedFolder.name} (${selectedFolder.id})');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NotesScreen(
              folderId: selectedFolder.id,
              shouldCreateNewNote: true,
            ),
          ),
        ).then((_) {
          _loadData();
        });
      }
    });
  }

  void _performSearch(String query) {
    _searchTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
      return;
    }
    setState(() {
      _isSearchLoading = true;
    });
    _searchTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final allNotes = await _pbService.getNotes();
        final filteredNotes = allNotes.where((record) {
          final title = (record.data['title'] ?? '').toString().toLowerCase();
          final content =
              (record.data['content'] ?? '').toString().toLowerCase();
          final searchQuery = query.toLowerCase();
          return title.contains(searchQuery) || content.contains(searchQuery);
        }).toList();
        List<Note> searchResults = [];
        for (var record in filteredNotes) {
          searchResults.add(Note(
            id: record.id,
            title: record.data['title'] ?? '',
            content: record.data['content'] ?? '',
            createdAt: DateTime.parse(record.created),
            updatedAt: DateTime.parse(record.updated),
            folderId: record.data['folder_id'],
            userId: record.data['user_id'],
          ));
        }
        setState(() {
          _searchResults = searchResults;
          _isSearchLoading = false;
        });
      } catch (e) {
        print('Error searching notes: $e');
        setState(() {
          _searchResults = [];
          _isSearchLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _currentIndex == 0
          ? _buildHomeContent()
          : _currentIndex == 1
              ? const CalendarScreen()
              : _currentIndex == 2
                  ? const NotificationsScreen()
                  : const ProfileScreen(),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _createNewNote,
          backgroundColor: Colors.purple,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        notchMargin: 8,
        color: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, 0),
                _buildNavItem(Icons.event, 1),
                const SizedBox(width: 48),
                _buildNavItem(Icons.notifications, 2),
                _buildNavItem(Icons.person, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.purple.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isSelected ? Colors.purple : Colors.grey,
          size: 24,
        ),
        onPressed: () => setState(() => _currentIndex = index),
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.purple,
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                kToolbarHeight -
                kBottomNavigationBarHeight -
                16, // Adjust for status bar, FAB, and padding
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildFolderSection(),
              const SizedBox(height: 24),
              _buildRecentNotesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'MEMORA',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            _isSearching
                ? Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search notes...',
                            hintStyle: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.grey[500],
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  _isSearching = false;
                                  _searchResults = [];
                                });
                                _searchController.clear();
                                _searchTimer?.cancel();
                              },
                            ),
                          ),
                          onChanged: _performSearch,
                          autofocus: true,
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, size: 24),
                      color: Colors.purple,
                      onPressed: () {
                        setState(() {
                          _isSearching = true;
                        });
                      },
                      tooltip: 'Search notes',
                    ),
                  ),
          ],
        ),
        if (_isSearching &&
            (_searchResults.isNotEmpty ||
                _isSearchLoading ||
                _searchController.text.isNotEmpty))
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.purple.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildSearchResults(),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearchLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.purple,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_searchController.text.isNotEmpty && _searchResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No notes found',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Try different keywords',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final note = _searchResults[index];
          // Ekstrak teks biasa untuk search results juga
          final plainTextContent = _extractPlainTextFromQuillContent(note.content);
          
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getNoteColor(index).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.note,
                color: _getNoteColor(index),
                size: 20,
              ),
            ),
            title: Text(
              note.title.isNotEmpty ? note.title : 'Untitled Note',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plainTextContent.isNotEmpty)
                  Text(
                    plainTextContent,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatSearchDate(note.updatedAt),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _isSearching = false;
                _searchResults = [];
              });
              _searchController.clear();
              _navigateToNoteDetail(note);
            },
          );
        },
      ),
    );
  }

  String _formatSearchDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0)
      return 'Today';
    else if (difference.inDays == 1)
      return 'Yesterday';
    else if (difference.inDays < 7)
      return '${difference.inDays} days ago';
    else
      return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildGreeting() {
    return FutureBuilder<String>(
      future: _pbService.getCurrentUsername(),
      builder: (context, snapshot) {
        final username = snapshot.data ?? 'human';
        return Text(
          'Hello $username, how are you today?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.grey[700],
          ),
        );
      },
    );
  }

  Widget _buildFolderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGreeting(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.purple.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My folders',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, size: 24),
                      color: Colors.purple,
                      onPressed: _showCreateFolderDialog,
                      tooltip: 'Create new folder',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildFolderGrid(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFolderGrid() {
    if (_folders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.folder_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No folders yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first folder to organize notes',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4, // Changed from 2.0 to 1.8 to give more height
      ),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return GestureDetector(
          onTap: () => _selectFolder(folder.id, folder.name),
          child: _buildFolderItem(folder: folder),
        );
      },
    );
  }

  void _showEditFolderDialog(Folder folder) {
    final nameController = TextEditingController(text: folder.name);
    String selectedColor = _getColorCode(folder.color);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.edit, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Folder',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: nameController,
                  style: const TextStyle(fontFamily: 'Poppins'),
                  decoration: InputDecoration(
                    labelText: 'Folder Name',
                    labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.purple,
                    ),
                    hintText: 'Enter folder name',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.grey[500],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Color: ',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      children: [
                        _colorOption(Colors.purple, '9C27B0', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                        _colorOption(Colors.blue, '1565C0', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                        _colorOption(Colors.red, 'C62828', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                        _colorOption(Colors.green, '2E7D32', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                        _colorOption(Colors.orange, 'EF6C00', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                      ],
                    ),
                  ),
                ],
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
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter folder name')),
                  );
                  return;
                }

                try {
                  print('Updating folder: ${folder.id}');
                  print('New name: ${nameController.text.trim()}');
                  print('New color: $selectedColor');
                  try {
                    await _pbService.updateFolderDirect(
                      folder.id,
                      nameController.text.trim(),
                      selectedColor,
                      'folder',
                    );
                  } catch (directError) {
                    print(
                        'Direct method failed, trying SDK method: $directError');
                    await _pbService.updateFolder(
                      folder.id,
                      nameController.text.trim(),
                      selectedColor,
                      'folder',
                    );
                  }

                  Navigator.pop(context);
                  await _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Folder updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  print('Error updating folder: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update folder: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
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
                'Update',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteFolderDialog(Folder folder) {
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
              'Delete Folder',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to delete "${folder.name}"?',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone and will delete all notes in this folder.',
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
                print('Deleting folder: ${folder.id}');
                try {
                  await _pbService.deleteFolderDirect(folder.id);
                } catch (directError) {
                  print(
                      'Direct method failed, trying SDK method: $directError');
                  await _pbService.deleteFolder(folder.id);
                }
                Navigator.pop(context);
                await _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Folder deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                print('Error deleting folder: $e');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete folder: ${e.toString()}'),
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
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getColorCode(Color color) {
    if (color == Colors.purple) return '9C27B0';
    if (color == Colors.blue) return '1565C0';
    if (color == Colors.red) return 'C62828';
    if (color == Colors.green) return '2E7D32';
    if (color == Colors.orange) return 'EF6C00';
    return '9C27B0';
  }

  Widget _buildFolderItem({
    required Folder folder,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            folder.color.withOpacity(0.1),
            folder.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: folder.color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: folder.color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: folder.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          folder.icon,
                          color: folder.color,
                          size: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        folder.name,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${folder.noteCount} notes',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showFolderOptionsMenu(context, folder),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
    );
  }

  void _showFolderOptionsMenu(BuildContext context, Folder folder) {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: folder.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      folder.icon,
                      color: folder.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${folder.noteCount} notes',
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
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Edit Folder',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    subtitle: Text(
                      'Change name and color',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditFolderDialog(folder);
                    },
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  ListTile(
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
                      'Delete Folder',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    subtitle: Text(
                      'Remove folder and all notes',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteFolderDialog(folder);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final nameController = TextEditingController();
    String selectedColor = '9C27B0';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.create_new_folder,
                    color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Create New Folder',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: nameController,
                  style: const TextStyle(fontFamily: 'Poppins'),
                  decoration: InputDecoration(
                    labelText: 'Folder Name',
                    labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.purple,
                    ),
                    hintText: 'Enter folder name',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.grey[500],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Color: ',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      children: [
                        _colorOption(Colors.purple, '9C27B0', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                        _colorOption(Colors.blue, '1565C0', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                        _colorOption(Colors.red, 'C62828', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                        _colorOption(Colors.green, '2E7D32', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                        _colorOption(Colors.orange, 'EF6C00', selectedColor,
                            (color) => setState(() => selectedColor = color)),
                      ],
                    ),
                  ),
                ],
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
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter folder name')),
                  );
                  return;
                }

                try {
                  print(
                      'Creating folder with name: ${nameController.text.trim()}');
                  print('Creating folder with color: $selectedColor');
                  final newFolder = await _pbService.createFolder(
                    nameController.text.trim(),
                    selectedColor,
                    'folder',
                  );
                  print('Folder created successfully: ${newFolder.id}');
                  Navigator.pop(context);
                  await _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Folder created successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  final createNote = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        'Folder Created',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                      content: Text(
                        'Do you want to create a note in "${nameController.text.trim()}"?',
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'No',
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
                            'Yes',
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (createNote == true) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotesScreen(
                          folderId: newFolder.id,
                          shouldCreateNewNote: true,
                        ),
                      ),
                    ).then((_) => _loadData());
                  }
                } catch (e) {
                  print('Error creating folder: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create folder: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
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
                'Create',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorOption(Color color, String colorCode, String selectedColor,
      Function(String) onSelect) {
    final isSelected = colorCode == selectedColor;
    return GestureDetector(
      onTap: () => onSelect(colorCode),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isSelected ? 0.4 : 0.2),
              blurRadius: isSelected ? 8 : 4,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 18,
              )
            : null,
      ),
    );
  }

  Widget _buildRecentNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Notes',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotesScreen(),
                    ),
                  ).then((_) => _loadData());
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _recentNotes.isEmpty
            ? Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.note_add,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notes yet',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first note to get started',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : _buildNoteGrid(_recentNotes),
      ],
    );
  }

  Widget _buildNoteGrid(List<Note> notes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return GestureDetector(
          onTap: () => _navigateToNoteDetail(note),
          child: _buildNoteItem(
            note: note,
            index: index,
          ),
        );
      },
    );
  }

  Widget _buildNoteItem({
    required Note note,
    required int index,
  }) {
    final Color backgroundColor = _getNoteColor(index);
    final Color textColor = index == 3 ? Colors.white : Colors.black87;
    
    // Ekstrak teks biasa dari konten Quill untuk Recent Notes
    final plainTextContent = _extractPlainTextFromQuillContent(note.content);

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              Text(
                _formatSearchDate(note.updatedAt),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note.title.isNotEmpty ? note.title : 'Untitled Note',
            style: TextStyle(
              fontFamily: 'Poppins',
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
              plainTextContent, // Menggunakan teks biasa yang diekstrak
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: textColor.withOpacity(0.8),
                height: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 10,
            ),
          ),
        ],
      ),
    );
  }

  Color _getNoteColor(int index) {
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