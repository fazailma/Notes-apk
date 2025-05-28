import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart' as universal_io; // Impor universal_io

class PocketbaseService {
  static final PocketbaseService _instance = PocketbaseService._internal();
  factory PocketbaseService() => _instance;
  PocketbaseService._internal();

  final PocketBase pb = PocketBase('http://127.0.0.1:8090');
  final ValueNotifier<bool> authState = ValueNotifier<bool>(false);

  Future<void> init() async {
    await _loadAuthFromStorage();
    pb.authStore.onChange.listen((_) {
      authState.value = pb.authStore.isValid;
      print('Auth state changed: ${authState.value}');
      print('Current user: ${pb.authStore.model}');
    });
  }

  Future<void> _loadAuthFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('pb_auth_token');
      final model = prefs.getString('pb_auth_model');

      if (token != null && token.isNotEmpty) {
        print('Found stored token, restoring session...');
        if (model != null && model.isNotEmpty) {
          final modelMap = jsonDecode(model);
          pb.authStore.save(token, RecordModel.fromJson(modelMap));
        } else {
          pb.authStore.save(token, null);
        }

        try {
          await pb.collection('users').authRefresh();
          print('Token valid, user restored: ${pb.authStore.model}');
          authState.value = true;
        } catch (e) {
          print('Token invalid or expired: $e');
          await logout();
        }
      } else {
        print('No stored token found');
        authState.value = false;
      }
    } catch (e) {
      print('Error loading auth data: $e');
      authState.value = false;
    }
  }

  Future<void> _saveAuthToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = pb.authStore.token;
      final model = pb.authStore.model?.toJson();

      if (token.isNotEmpty) {
        await prefs.setString('pb_auth_token', token);
        if (model != null) {
          await prefs.setString('pb_auth_model', jsonEncode(model));
        }
        print('Auth data saved to storage');
      } else {
        await prefs.remove('pb_auth_token');
        await prefs.remove('pb_auth_model');
        print('Auth data cleared from storage');
      }
    } catch (e) {
      print('Error saving auth data: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final authData = await pb.collection('users').authWithPassword(email, password);
      print('Login successful');
      print('Current User: ${pb.authStore.model}');
      await _saveAuthToStorage();
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    try {
      await pb.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': name,
      });
      print('User registered successfully');
      return await login(email, password);
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    pb.authStore.clear();
    await _saveAuthToStorage();
    print('Logged out');
  }

  bool get isLoggedIn => pb.authStore.isValid;
  dynamic get currentUser => pb.authStore.model;

  Future<String?> uploadProfilePicture(io.File imageFile) async {
    if (!isLoggedIn) {
      print('User tidak login');
      throw Exception('User is not logged in');
    }

    try {
      final userId = pb.authStore.model.id;
      print('Mengunggah gambar untuk user ID: $userId');

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('http://127.0.0.1:8090/api/collections/users/records/$userId'),
      );

      // Gunakan universal_io untuk kompatibilitas web
      final bytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: imageFile.path.split('/').last,
      ));
      request.headers['Authorization'] = 'Bearer ${pb.authStore.token}';
      request.headers['Content-Type'] = 'multipart/form-data';

      print('Mengirim request ke server...');
      final response = await request.send();
      final responseData = await http.Response.fromStream(response);

      print('Status code: ${response.statusCode}');
      print('Response body: ${responseData.body}');

      if (response.statusCode == 200) {
        final updatedRecord = jsonDecode(responseData.body);
        if (updatedRecord['avatar'] == null || updatedRecord['avatar'].isEmpty) {
          print('Field avatar kosong di response');
          throw Exception('Field avatar tidak ditemukan di response');
        }
        final avatarUrl = 'http://127.0.0.1:8090/api/files/users/$userId/${updatedRecord['avatar']}';
        print('Gambar berhasil diunggah: $avatarUrl');
        return avatarUrl;
      } else {
        print('Gagal unggah: ${responseData.body}');
        throw Exception('Gagal unggah gambar: Status ${response.statusCode}, ${responseData.body}');
      }
    } catch (e) {
      print('Error unggah gambar: $e');
      throw Exception('Gagal unggah gambar: $e');
    }
  }

  Future<RecordModel> getProfile() async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }

    try {
      final profile = await pb.collection('users').getOne(pb.authStore.model.id);
      if (profile.data['avatar'] != null && profile.data['avatar'].isNotEmpty) {
        profile.data['avatar'] = 'http://127.0.0.1:8090/api/files/users/${profile.id}/${profile.data['avatar']}';
      }
      return profile;
    } catch (e) {
      print('Error getting profile: $e');
      try {
        await pb.collection('users').authRefresh();
        final profile = await pb.collection('users').getOne(pb.authStore.model.id);
        if (profile.data['avatar'] != null && profile.data['avatar'].isNotEmpty) {
          profile.data['avatar'] = 'http://127.0.0.1:8090/api/files/users/${profile.id}/${profile.data['avatar']}';
        }
        return profile;
      } catch (refreshError) {
        print('Auth refresh failed: $refreshError');
        throw Exception('Failed to get profile: $e');
      }
    }
  }

  Future<void> updateProfile(String name, String email) async {
    if (!isLoggedIn) {
      print('User tidak login saat mencoba update profil');
      throw Exception('User is not logged in');
    }
    try {
      print('Mengupdate profil: name = $name, email = $email');
      final currentProfile = await getProfile();
      final currentEmail = currentProfile.data['email'] as String;
      if (email != currentEmail) {
        print('Email berubah dari $currentEmail ke $email, memeriksa validasi...');
      }
      final response = await pb.collection('users').update(pb.authStore.model.id, body: {
        'name': name,
        'email': email,
      });
      print('Profil berhasil diupdate: $response');
      await _saveAuthToStorage(); // Perbarui autentikasi
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  Future<String> getCurrentUsername() async {
    if (!isLoggedIn) {
      return 'Guest';
    }
    try {
      final profile = await getProfile();
      return profile.data['name'] ?? 'User';
    } catch (e) {
      print('Error getting username: $e');
      return 'User';
    }
  }

  Future<List<RecordModel>> getNotes() async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final userId = pb.authStore.model.id;
      print('Fetching notes for user ID: $userId');
      final notes = await pb.collection('catatan').getFullList(
            sort: '-created',
            filter: 'user_id = "$userId"',
          );
      print('Fetched ${notes.length} notes');
      return notes;
    } catch (e) {
      print('Error getting notes: $e');
      throw Exception('Failed to get notes: $e');
    }
  }

  Future<List<RecordModel>> getNotesByFolder(String folderId) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      print('Fetching notes for folder: $folderId');
      print('Current user ID: ${pb.authStore.model.id}');
      final notes = await pb.collection('catatan').getFullList(
            sort: '-created',
            filter: 'user_id = "${pb.authStore.model.id}" && folder_id = "$folderId"',
          );
      print('Found ${notes.length} notes in folder $folderId');
      return notes;
    } catch (e) {
      print('Error getting notes by folder: $e');
      throw Exception('Failed to get notes by folder: $e');
    }
  }

  Future<List<RecordModel>> getRecentNotes({int limit = 10}) async {
    if (!isLoggedIn) {
      print('User not logged in when trying to get recent notes');
      throw Exception('User is not logged in');
    }
    try {
      print('Fetching recent notes for user ID: ${pb.authStore.model.id}');
      final response = await pb.collection('catatan').getList(
            page: 1,
            perPage: limit,
            sort: '-updated',
            filter: 'user_id = "${pb.authStore.model.id}"',
          );
      print('Recent notes fetched: ${response.items.length}');
      return response.items;
    } catch (e) {
      print('Error getting recent notes: $e');
      throw Exception('Failed to get recent notes: $e');
    }
  }

  Future<RecordModel> createNote(String title, String content, {String? folderId}) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final data = {
        'title': title,
        'content': content,
        'user_id': pb.authStore.model.id,
      };
      if (folderId != null && folderId.isNotEmpty) {
        data['folder_id'] = folderId;
        print('Creating note with folder_id: $folderId');
      } else {
        print('Creating note without folder_id');
      }
      final result = await pb.collection('catatan').create(body: data);
      print('Note created with ID: ${result.id}');
      return result;
    } catch (e) {
      print('Error creating note: $e');
      throw Exception('Failed to create note: $e');
    }
  }

  Future<RecordModel> updateNote(String id, String title, String content) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final note = await pb.collection('catatan').getOne(id);
      if (note.data['user_id'] != pb.authStore.model.id) {
        throw Exception('You do not have permission to update this note');
      }
      return await pb.collection('catatan').update(id, body: {
        'title': title,
        'content': content,
      });
    } catch (e) {
      print('Error updating note: $e');
      throw Exception('Failed to update note: $e');
    }
  }

  Future<void> deleteNote(String id) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final note = await pb.collection('catatan').getOne(id);
      if (note.data['user_id'] != pb.authStore.model.id) {
        throw Exception('You do not have permission to delete this note');
      }
      await pb.collection('catatan').delete(id);
      print('Note deleted: $id');
    } catch (e) {
      print('Error deleting note: $e');
      throw Exception('Failed to delete note: $e');
    }
  }

  Future<RecordModel> getNoteById(String id) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final note = await pb.collection('catatan').getOne(id);
      if (note.data['user_id'] != pb.authStore.model.id) {
        throw Exception('You do not have permission to access this note');
      }
      return note;
    } catch (e) {
      print('Error getting note: $e');
      throw Exception('Failed to get note: $e');
    }
  }

  Future<List<RecordModel>> getFolders() async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final folders = await pb.collection('folders').getFullList(
            sort: 'name',
            filter: 'user = "${pb.authStore.model.id}"',
          );
      print('Fetched ${folders.length} folders');
      return folders;
    } catch (e) {
      print('Error getting folders: $e');
      throw Exception('Failed to get folders: $e');
    }
  }

  Future<RecordModel> createFolder(String name, String color, String icon) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      return await pb.collection('folders').create(body: {
        'name': name,
        'color': color,
        'icon': icon,
        'user': pb.authStore.model.id,
      });
    } catch (e) {
      print('Error creating folder: $e');
      throw Exception('Failed to create folder: $e');
    }
  }

  Future<RecordModel> updateFolder(String id, String name, String color, String icon) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      return await pb.collection('folders').update(id, body: {
        'name': name,
        'color': color,
        'icon': icon,
      });
    } catch (e) {
      print('Error updating folder: $e');
      throw Exception('Failed to update folder: $e');
    }
  }

  Future<void> deleteFolder(String id) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      await pb.collection('folders').delete(id);
      print('Folder deleted: $id');
    } catch (e) {
      print('Error deleting folder: $e');
      throw Exception('Failed to delete folder: $e');
    }
  }

  Future<List<RecordModel>> getEvents() async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final userId = pb.authStore.model.id;
      print('Fetching events for user ID: $userId');
      final events = await pb.collection('events').getFullList(
            sort: 'start_date',
            filter: 'user_id = "$userId"',
          );
      print('Fetched ${events.length} events');
      return events;
    } catch (e) {
      print('Error getting events: $e');
      throw Exception('Failed to get events: $e');
    }
  }

  Future<List<RecordModel>> getEventsByDateRange(DateTime start, DateTime end) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final userId = pb.authStore.model.id;
      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();
      print('Fetching events between $startStr and $endStr');
      final events = await pb.collection('events').getFullList(
            sort: 'start_date',
            filter:
                'user_id = "$userId" && ((start_date >= "$startStr" && start_date <= "$endStr") || (end_date >= "$startStr" && end_date <= "$endStr") || (start_date <= "$startStr" && end_date >= "$endStr"))',
          );
      print('Fetched ${events.length} events in date range');
      return events;
    } catch (e) {
      print('Error getting events by date range: $e');
      throw Exception('Failed to get events by date range: $e');
    }
  }

  Future<List<RecordModel>> getEventsByDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
    return getEventsByDateRange(start, end);
  }

  Future<List<RecordModel>> getEventsByMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = month < 12
        ? DateTime(year, month + 1, 0, 23, 59, 59)
        : DateTime(year + 1, 1, 0, 23, 59, 59);
    return getEventsByDateRange(start, end);
  }

  Future<RecordModel> createEvent({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    bool allDay = false,
    String? color,
    String? location,
    int? reminder,
  }) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final data = {
        'title': title,
        'description': description,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'all_day': allDay,
        'user_id': pb.authStore.model.id,
      };
      if (color != null) data['color'] = color;
      if (location != null) data['location'] = location;
      if (reminder != null) data['reminder'] = reminder;
      final result = await pb.collection('events').create(body: data);
      print('Event created with ID: ${result.id}');
      return result;
    } catch (e) {
      print('Error creating event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  Future<RecordModel> updateEvent({
    required String id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? allDay,
    String? color,
    String? location,
    int? reminder,
  }) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final event = await pb.collection('events').getOne(id);
      if (event.data['user_id'] != pb.authStore.model.id) {
        throw Exception('You do not have permission to update this event');
      }
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (startDate != null) data['start_date'] = startDate.toIso8601String();
      if (endDate != null) data['end_date'] = endDate.toIso8601String();
      if (allDay != null) data['all_day'] = allDay;
      if (color != null) data['color'] = color;
      if (location != null) data['location'] = location;
      if (reminder != null) data['reminder'] = reminder;
      return await pb.collection('events').update(id, body: data);
    } catch (e) {
      print('Error updating event: $e');
      throw Exception('Failed to update event: $e');
    }
  }

  Future<void> deleteEvent(String id) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final event = await pb.collection('events').getOne(id);
      if (event.data['user_id'] != pb.authStore.model.id) {
        throw Exception('You do not have permission to delete this event');
      }
      await pb.collection('events').delete(id);
      print('Event deleted: $id');
    } catch (e) {
      print('Error deleting event: $e');
      throw Exception('Failed to delete event: $e');
    }
  }

  Future<RecordModel> getEventById(String id) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final event = await pb.collection('events').getOne(id);
      if (event.data['user_id'] != pb.authStore.model.id) {
        throw Exception('You do not have permission to access this event');
      }
      return event;
    } catch (e) {
      print('Error getting event: $e');
      throw Exception('Failed to get event: $e');
    }
  }
}