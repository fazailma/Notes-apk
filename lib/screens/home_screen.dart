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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PocketbaseService _pbService = PocketbaseService();
  List<Folder> _folders = [];
  List<Note> _recentNotes = []; // Hanya untuk recent notes
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Pastikan service sudah diinisialisasi
    _initService();
  }

  Future<void> _initService() async {
    try {
      // Inisialisasi service terlebih dahulu jika belum
      await _pbService.init();
      
      // Kemudian load data
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
      // Check if user is logged in
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

      // PENTING: Cetak user ID yang sedang login untuk debugging
      print('Loading data for user ID: ${_pbService.currentUser.id}');
      
      // Load folders (folders diambil berdasarkan user_id)
      print('Fetching folders');
      final folderRecords = await _pbService.getFolders();
      print('Fetched ${folderRecords.length} folders');
      
      // Convert RecordModel to Folder objects
      List<Folder> folders = [];
      for (var record in folderRecords) {
        // Parse color
        Color folderColor = Colors.blue;
        try {
          final colorStr = record.data['color'] ?? '#1565C0';
          final hexCode = colorStr.replaceFirst('#', '');
          folderColor = Color(int.parse('0xFF$hexCode'));
        } catch (e) {
          print('Error parsing color: $e');
        }
        
        // Parse icon
        IconData folderIcon = Icons.folder;
        try {
          final iconStr = record.data['icon'] ?? 'folder';
          if (iconStr == 'note') folderIcon = Icons.note;
          else if (iconStr == 'work') folderIcon = Icons.work;
          else if (iconStr == 'favorite') folderIcon = Icons.favorite;
          else if (iconStr == 'star') folderIcon = Icons.star;
        } catch (e) {
          print('Error parsing icon: $e');
        }
        
        folders.add(Folder(
          id: record.id,
          name: record.data['name'] ?? 'Unnamed Folder',
          color: folderColor,
          icon: folderIcon,
          noteCount: 0, // Kita akan memperbarui ini nanti
        ));
      }
      
      // Mengambil catatan terbaru untuk section "Recent Notes"
      print('Fetching recent notes');
      final recentNoteRecords = await _pbService.getRecentNotes(limit: 4);
      print('Fetched ${recentNoteRecords.length} recent notes');
      
      // Konversi ke objek Note
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
      
      // Hitung jumlah catatan untuk setiap folder
      // Catatan: Kita hanya bisa menghitung berdasarkan catatan terbaru yang sudah dimuat,
      // untuk akurasi lengkap, kita perlu memuat semua catatan.
      if (folders.isNotEmpty && recentNotes.isNotEmpty) {
        // Kita akan mengakses PocketBase sekali lagi untuk mendapatkan jumlah catatan per folder
        for (int i = 0; i < folders.length; i++) {
          try {
            final notesInFolder = await _pbService.getNotesByFolder(folders[i].id);
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

  // PERUBAHAN: Navigasi ke NotesScreen ketika folder dipilih
  void _selectFolder(String folderId, String folderName) {
    print('Selected folder ID: $folderId, Name: $folderName');
    
    // Navigasi ke NotesScreen dengan membawa folderId
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotesScreen(folderId: folderId),
      ),
    ).then((_) {
      // Reload data ketika kembali dari NotesScreen
      _loadData();
    });
  }

  void _navigateToNoteDetail(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    ).then((_) => _loadData()); // Reload notes when returning from note detail
  }

  void _createNewNote() {
    if (!_pbService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus login terlebih dahulu')),
      );
      return;
    }
    
    // Menampilkan dialog pemilihan folder sebelum membuat catatan
    _showSelectFolderDialog();
  }
  
  // Dialog untuk memilih folder saat membuat catatan baru
  void _showSelectFolderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: _folders.isEmpty 
              ? const Text('Tidak ada folder. Silakan buat folder terlebih dahulu.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _folders.length,
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    return ListTile(
                      leading: Icon(folder.icon, color: folder.color),
                      title: Text(folder.name),
                      onTap: () {
                        Navigator.pop(context, folder);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          if (_folders.isEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCreateFolderDialog();
              },
              child: const Text('Buat Folder'),
            ),
        ],
      ),
    ).then((selectedFolder) {
      if (selectedFolder != null && selectedFolder is Folder) {
        // Membuat catatan baru dengan folder yang dipilih
        final newNote = Note(
          id: '', // ID will be assigned by PocketBase
          title: '',
          content: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          folderId: selectedFolder.id,
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
        ).then((result) {
          if (result != null && result is Note) {
            // Create the note in PocketBase
            print('Creating note with title: ${result.title}');
            print('Note folder ID: ${result.folderId}');
            print('Note user ID: ${result.userId}');
            
            _pbService.createNote(
              result.title, 
              result.content,
              folderId: result.folderId,
            ).then((_) {
              // Reload notes to get the new note with the correct ID
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Catatan berhasil disimpan')),
              );
            }).catchError((e) {
              print('Error creating note: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gagal menyimpan catatan: ${e.toString()}')),
              );
            });
          }
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
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        notchMargin: 8,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  Icons.home,
                  color: _currentIndex == 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                onPressed: () => setState(() => _currentIndex = 0),
              ),
              IconButton(
                icon: Icon(
                  Icons.event,
                  color: _currentIndex == 1
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                onPressed: () => setState(() => _currentIndex = 1),
              ),
              const SizedBox(width: 48),
              IconButton(
                icon: Icon(
                  Icons.notifications,
                  color: _currentIndex == 2
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                onPressed: () => setState(() => _currentIndex = 2),
              ),
              IconButton(
                icon: Icon(
                  Icons.person,
                  color: _currentIndex == 3
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                onPressed: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFolderSection(),
            const SizedBox(height: 24),
            _buildRecentNotesSection(),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit,
              color: Colors.blue[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'MEMORA',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[600],
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.search, size: 24),
          onPressed: () {
            // Navigasi ke halaman semua catatan dengan opsi pencarian
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotesScreen(), // Tanpa folderId untuk semua catatan
              ),
            ).then((_) => _loadData());
          },
          tooltip: 'Cari catatan',
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return FutureBuilder<String>(
      future: _pbService.getCurrentUsername(),
      builder: (context, snapshot) {
        final username = snapshot.data ?? 'faza';
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Text(
            'Hello $username, how are you today?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My folders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _showCreateFolderDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFolderGrid(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFolderGrid() {
    if (_folders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No folders yet. Create your first folder!',
            style: TextStyle(color: Colors.grey),
          ),
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
        childAspectRatio: 1.5,
      ),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return GestureDetector(
          onTap: () => _selectFolder(folder.id, folder.name),
          child: _buildFolderItem(
            folder: folder,
            index: index,
          ),
        );
      },
    );
  }

  Widget _buildFolderItem({
    required Folder folder,
    required int index,
  }) {
    // Get pastel color based on index
    final Color backgroundColor = _getFolderColor(index);
    
    return Container(
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
          // Tambahkan jumlah catatan
          Text(
            '${folder.noteCount} notes',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
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

  void _showCreateFolderDialog() {
    final nameController = TextEditingController();
    String selectedColor = '1565C0'; // Default blue color
    String selectedIcon = 'folder'; // Default folder icon
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Folder Name',
                  hintText: 'Enter folder name',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Color: '),
                  const SizedBox(width: 8),
                  // Simplified color picker - add more colors as needed
                  Wrap(
                    spacing: 8,
                    children: [
                      _colorOption(Colors.blue, '1565C0', selectedColor, 
                        (color) => setState(() => selectedColor = color)),
                      _colorOption(Colors.red, 'C62828', selectedColor,
                        (color) => setState(() => selectedColor = color)),
                      _colorOption(Colors.green, '2E7D32', selectedColor,
                        (color) => setState(() => selectedColor = color)),
                      _colorOption(Colors.orange, 'EF6C00', selectedColor,
                        (color) => setState(() => selectedColor = color)),
                      _colorOption(Colors.purple, '6A1B9A', selectedColor,
                        (color) => setState(() => selectedColor = color)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Icon: '),
                  const SizedBox(width: 8),
                  // Simplified icon picker - add more icons as needed
                  Wrap(
                    spacing: 8,
                    children: [
                      _iconOption(Icons.folder, 'folder', selectedIcon,
                        (icon) => setState(() => selectedIcon = icon)),
                      _iconOption(Icons.work, 'work', selectedIcon,
                        (icon) => setState(() => selectedIcon = icon)),
                      _iconOption(Icons.favorite, 'favorite', selectedIcon,
                        (icon) => setState(() => selectedIcon = icon)),
                      _iconOption(Icons.note, 'note', selectedIcon,
                        (icon) => setState(() => selectedIcon = icon)),
                      _iconOption(Icons.star, 'star', selectedIcon,
                        (icon) => setState(() => selectedIcon = icon)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Validate input
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter folder name')),
                  );
                  return;
                }
                
                // Create folder in PocketBase
                try {
                  final newFolder = await _pbService.createFolder(
                    nameController.text.trim(),
                    selectedColor,
                    selectedIcon,
                  );
                  
                  // Convert to Folder model
                  final folderColor = Color(int.parse('0xFF$selectedColor'));
                  IconData folderIcon = Icons.folder;
                  if (selectedIcon == 'note') folderIcon = Icons.note;
                  else if (selectedIcon == 'work') folderIcon = Icons.work;
                  else if (selectedIcon == 'favorite') folderIcon = Icons.favorite;
                  else if (selectedIcon == 'star') folderIcon = Icons.star;
                  
                  final folder = Folder(
                    id: newFolder.id,
                    name: newFolder.data['name'],
                    color: folderColor,
                    icon: folderIcon,
                    noteCount: 0,
                  );
                  
                  // Add to folders list
                  this.setState(() {
                    _folders.add(folder);
                  });
                  
                  Navigator.pop(context);
                  
                  // Tanya pengguna apakah ingin membuat catatan di folder baru
                  final createNote = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Folder Created'),
                      content: Text('Do you want to create a note in "${folder.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Yes'),
                        ),
                      ],
                    ),
                  );
                  
                  if (createNote == true) {
                    // Buat catatan baru di folder yang baru dibuat
                    final newNote = Note(
                      id: '',
                      title: '',
                      content: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                      folderId: folder.id,
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
                    ).then((result) {
                      if (result != null && result is Note) {
                        _pbService.createNote(
                          result.title,
                          result.content,
                          folderId: result.folderId,
                        ).then((_) {
                          _loadData();
                        }).catchError((e) {
                          print('Error creating note: $e');
                        });
                      }
                    });
                  }
                } catch (e) {
                  print('Error creating folder: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create folder: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorOption(Color color, String colorCode, String selectedColor, Function(String) onSelect) {
    final isSelected = colorCode == selectedColor;
    return GestureDetector(
      onTap: () => onSelect(colorCode),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              spreadRadius: 1,
            )
          ] : null,
        ),
      ),
    );
  }

  Widget _iconOption(IconData icon, String iconName, String selectedIcon, Function(String) onSelect) {
    final isSelected = iconName == selectedIcon;
    return GestureDetector(
      onTap: () => onSelect(iconName),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.blue : Colors.grey,
        ),
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
            const Text(
              'Recent Notes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigasi ke halaman semua catatan
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotesScreen(), // Tanpa folderId untuk semua catatan
                  ),
                ).then((_) => _loadData());
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Menampilkan catatan terbaru
        _recentNotes.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No notes yet. Create your first note!',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
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
    // Get color based on index to match the design
    final Color backgroundColor = _getNoteColor(index);
    final Color textColor = index == 3 ? Colors.white : Colors.black87;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.title.isNotEmpty ? note.title : 'Untitled Note',
            style: TextStyle(
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
              note.content,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
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
    // Return colors based on index to match the image
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