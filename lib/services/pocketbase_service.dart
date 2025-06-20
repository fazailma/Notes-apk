import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart' as universal_io;

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
      throw Exception('Gagal login: $e');
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
      throw Exception('Gagal register: $e');
    }
  }

  Future<void> logout() async {
    pb.authStore.clear();
    await _saveAuthToStorage();
    print('Logged out');
  }

  bool get isLoggedIn => pb.authStore.isValid;
  dynamic get currentUser => pb.authStore.model;

  // Method untuk cek koneksi ke server
  Future<bool> checkServerConnection() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8090/api/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Server connection check failed: $e');
      return false;
    }
  }

  // Method tambahan untuk refresh auth token jika diperlukan
  Future<bool> refreshAuthToken() async {
    try {
      if (pb.authStore.isValid) {
        await pb.collection('users').authRefresh();
        await _saveAuthToStorage();
        print('Auth token refreshed successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('Failed to refresh auth token: $e');
      return false;
    }
  }

  // Untuk platform mobile (Android/iOS)
  Future<String?> uploadProfilePicture(universal_io.File imageFile) async {
    if (!isLoggedIn) {
      print('User tidak login');
      throw Exception('User is not logged in');
    }

    try {
      final userId = pb.authStore.model!.id;
      print('Mengunggah gambar untuk user ID: $userId');

      if (!await imageFile.exists()) {
        throw Exception('File gambar tidak ditemukan');
      }
      if (imageFile.lengthSync() > 10 * 1024 * 1024) {
        throw Exception('Ukuran file melebihi 10MB');
      }

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('http://127.0.0.1:8090/api/collections/users/records/$userId'),
      );

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
        
        // Update authStore dengan data terbaru
        pb.authStore.save(pb.authStore.token, RecordModel.fromJson(updatedRecord));
        await _saveAuthToStorage();
        
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

  // Untuk platform web
  Future<String?> uploadProfilePictureWeb(XFile imageFile) async {
    if (!isLoggedIn) {
      print('User tidak login');
      throw Exception('User is not logged in');
    }

    try {
      final userId = pb.authStore.model!.id;
      print('Mengunggah gambar untuk user ID: $userId (web)');

      final bytes = await imageFile.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw Exception('Ukuran file melebihi 10MB');
      }

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('http://127.0.0.1:8090/api/collections/users/records/$userId'),
      );

      request.files.add(http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: imageFile.name,
      ));
      request.headers['Authorization'] = 'Bearer ${pb.authStore.token}';
      request.headers['Content-Type'] = 'multipart/form-data';

      print('Mengirim request ke server (web)...');
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
        
        // Update authStore dengan data terbaru
        pb.authStore.save(pb.authStore.token, RecordModel.fromJson(updatedRecord));
        await _saveAuthToStorage();
        
        final avatarUrl = 'http://127.0.0.1:8090/api/files/users/$userId/${updatedRecord['avatar']}';
        print('Gambar berhasil diunggah (web): $avatarUrl');
        return avatarUrl;
      } else {
        print('Gagal unggah (web): ${responseData.body}');
        throw Exception('Gagal unggah gambar: Status ${response.statusCode}, ${responseData.body}');
      }
    } catch (e) {
      print('Error unggah gambar (web): $e');
      throw Exception('Gagal unggah gambar: $e');
    }
  }

  Future<RecordModel> getProfile() async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }

    try {
      final profile = await pb.collection('users').getOne(pb.authStore.model!.id);
      if (profile.data['avatar'] != null && profile.data['avatar'].isNotEmpty) {
        profile.data['avatar'] = 'http://127.0.0.1:8090/api/files/users/${profile.id}/${profile.data['avatar']}';
      }
      return profile;
    } catch (e) {
      print('Error getting profile: $e');
      try {
        await pb.collection('users').authRefresh();
        final profile = await pb.collection('users').getOne(pb.authStore.model!.id);
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

  // 🔥 FIXED: Simple and reliable email validation
  bool _isValidEmail(String email) {
    // Simple but effective email validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  // 🔥 FIXED: Enhanced updateProfile method with better validation and error handling
  Future<RecordModel> updateProfile(String name, String email) async {
    if (!isLoggedIn) {
      print('User tidak login saat mencoba update profil');
      throw Exception('User is not logged in');
    }
    
    try {
      print('🚀 Starting profile update...');
      print('📝 Name: $name');
      print('📧 Email: $email');
      
      final userId = pb.authStore.model!.id;
      final currentUser = pb.authStore.model!;
      
      // 🔍 Enhanced input validation
      if (name.trim().isEmpty) {
        throw Exception('Name cannot be empty');
      }
      
      if (email.trim().isEmpty) {
        throw Exception('Email cannot be empty');
      }
      
      // 🔍 Simple email validation
      if (!_isValidEmail(email)) {
        throw Exception('Invalid email format. Please use format: user@domain.com');
      }

      // 🔍 Check current data
      final currentEmail = currentUser.data['email'] as String? ?? '';
      final currentName = currentUser.data['name'] as String? ?? '';
      final isEmailChanged = email.trim().toLowerCase() != currentEmail.toLowerCase();
      final isNameChanged = name.trim() != currentName;
      
      print('📊 Current email: $currentEmail');
      print('📊 New email: $email');
      print('📊 Email changed: $isEmailChanged');
      print('📊 Current name: $currentName');
      print('📊 New name: $name');
      print('📊 Name changed: $isNameChanged');
      
      // If no changes
      if (!isEmailChanged && !isNameChanged) {
        throw Exception('No changes detected');
      }
      
      // 🔍 Check email uniqueness if email changed
      if (isEmailChanged) {
        try {
          print('🔍 Checking email uniqueness...');
          final emailCheck = await pb.collection('users').getList(
            filter: 'email = "${email.trim()}" && id != "$userId"',
            perPage: 1,
          );
          if (emailCheck.items.isNotEmpty) {
            throw Exception('Email is already in use by another user');
          }
          print('✅ Email is unique');
        } catch (e) {
          if (e.toString().contains('Email is already in use')) {
            rethrow;
          }
          print('⚠️ Warning: Could not check email uniqueness: $e');
        }
      }
      
      // 🛠️ Prepare update data with proper field mapping
      final updateData = <String, dynamic>{};
      
      if (isNameChanged) {
        updateData['name'] = name.trim();
      }
      
      if (isEmailChanged) {
        // 🔥 FIXED: Add all required email fields for PocketBase
        updateData['email'] = email.trim().toLowerCase(); // Normalize email
        // Some PocketBase setups require emailConfirm field
        updateData['emailConfirm'] = email.trim().toLowerCase();
        // Mark email as verified if it was previously verified
        if (currentUser.data['verified'] == true) {
          updateData['verified'] = true;
        }
      }
      
      print('📦 Update data prepared: $updateData');
      
      // 🔄 Try multiple update methods for better compatibility
      RecordModel? updatedRecord;
      Exception? lastError;
      
      // Method 1: Try SDK with enhanced error handling
      try {
        print('🔄 Method 1: Using PocketBase SDK...');
        
        // Refresh token before update
        await pb.collection('users').authRefresh();
        print('✅ Token refreshed');
        
        updatedRecord = await pb.collection('users').update(userId, body: updateData);
        print('✅ Profile updated successfully via SDK');
        
      } catch (sdkError) {
        print('❌ SDK Error: $sdkError');
        lastError = Exception('SDK Error: $sdkError');
        
        // Method 2: Try direct HTTP with enhanced headers
        try {
          print('🔄 Method 2: Using direct HTTP request...');
          
          final response = await http.patch(
            Uri.parse('http://127.0.0.1:8090/api/collections/users/records/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${pb.authStore.token}',
              'Accept': 'application/json',
              'User-Agent': 'Flutter-App/1.0',
            },
            body: jsonEncode(updateData),
          );
          
          print('📡 HTTP Response Status: ${response.statusCode}');
          print('📡 HTTP Response Headers: ${response.headers}');
          print('📡 HTTP Response Body: ${response.body}');
          
          if (response.statusCode == 200) {
            final updatedData = jsonDecode(response.body);
            updatedRecord = RecordModel.fromJson(updatedData);
            print('✅ Profile updated successfully via HTTP');
            
          } else {
            // 🔍 Enhanced error parsing
            String errorMessage = _parseErrorResponse(response);
            throw Exception(errorMessage);
          }
          
        } catch (httpError) {
          print('❌ HTTP Error: $httpError');
          lastError = Exception('HTTP Error: $httpError');
          
          // Method 3: Try with minimal data
          try {
            print('🔄 Method 3: Using minimal update data...');
            
            final minimalData = <String, dynamic>{};
            if (isNameChanged) minimalData['name'] = name.trim();
            if (isEmailChanged) minimalData['email'] = email.trim().toLowerCase();
            
            final response = await http.patch(
              Uri.parse('http://127.0.0.1:8090/api/collections/users/records/$userId'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${pb.authStore.token}',
              },
              body: jsonEncode(minimalData),
            );
            
            print('📡 Minimal HTTP Response Status: ${response.statusCode}');
            print('📡 Minimal HTTP Response Body: ${response.body}');
            
            if (response.statusCode == 200) {
              final updatedData = jsonDecode(response.body);
              updatedRecord = RecordModel.fromJson(updatedData);
              print('✅ Profile updated successfully via minimal HTTP');
            } else {
              String errorMessage = _parseErrorResponse(response);
              throw Exception(errorMessage);
            }
            
          } catch (minimalError) {
            print('❌ Minimal Error: $minimalError');
            lastError = Exception('All methods failed. Last error: $minimalError');
          }
        }
      }
      
      // 🔍 Check if any method succeeded
      if (updatedRecord == null) {
        throw lastError ?? Exception('Failed to update profile: Unknown error');
      }
      
      // 🔄 Update authStore with fresh data
      pb.authStore.save(pb.authStore.token, updatedRecord);
      await _saveAuthToStorage();
      
      print('✅ Profile update completed successfully');
      return updatedRecord;
      
    } catch (e) {
      print('💥 Error updating profile: $e');
      
      // 🔍 Clean up error message
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      
      // 🔍 Handle specific PocketBase errors with user-friendly messages
      if (errorMessage.contains('validation_not_unique') || 
          errorMessage.contains('already in use') ||
          errorMessage.contains('email_not_unique')) {
        errorMessage = 'Email is already in use by another user';
      } else if (errorMessage.contains('validation_invalid_email') ||
                 errorMessage.contains('invalid email format')) {
        errorMessage = 'Invalid email format. Please use format: user@domain.com';
      } else if (errorMessage.contains('validation_required')) {
        errorMessage = 'All fields are required';
      } else if (errorMessage.contains('SocketException') || 
                 errorMessage.contains('Failed to fetch') || 
                 errorMessage.contains('NetworkError') ||
                 errorMessage.contains('Connection refused')) {
        errorMessage = 'Cannot connect to server. Please check your internet connection.';
      } else if (errorMessage.contains('401') || errorMessage.contains('Unauthorized')) {
        errorMessage = 'Your session has expired. Please login again.';
      } else if (errorMessage.contains('403') || errorMessage.contains('Forbidden')) {
        errorMessage = 'You do not have permission to update this profile.';
      } else if (errorMessage.contains('400') || errorMessage.contains('Bad Request')) {
        errorMessage = 'Invalid data provided. Please check your input.';
      }
      
      throw Exception(errorMessage);
    }
  }

  // 🔍 Enhanced error response parser
  String _parseErrorResponse(http.Response response) {
    try {
      final errorData = jsonDecode(response.body);
      
      // Handle PocketBase error format
      if (errorData['message'] != null) {
        return errorData['message'].toString();
      }
      
      if (errorData['data'] != null) {
        final data = errorData['data'];
        
        // Handle field-specific errors
        if (data['email'] != null) {
          final emailError = data['email'];
          if (emailError['message'] != null) {
            return 'Email: ${emailError['message']}';
          } else if (emailError['code'] != null) {
            switch (emailError['code']) {
              case 'validation_invalid_email':
                return 'Invalid email format';
              case 'validation_not_unique':
                return 'Email is already in use by another user';
              case 'validation_required':
                return 'Email is required';
              default:
                return 'Email error: ${emailError['code']}';
            }
          }
        }
        
        if (data['name'] != null) {
          final nameError = data['name'];
          if (nameError['message'] != null) {
            return 'Name: ${nameError['message']}';
          } else if (nameError['code'] == 'validation_required') {
            return 'Name is required';
          }
        }
        
        return 'Validation error: ${data.toString()}';
      }
      
      // Fallback based on status code
      switch (response.statusCode) {
        case 400:
          return 'Invalid data provided. Please check your input.';
        case 401:
          return 'Your session has expired. Please login again.';
        case 403:
          return 'You do not have permission to perform this action.';
        case 404:
          return 'Profile not found.';
        case 422:
          return 'Data validation failed. Please check your input.';
        case 500:
          return 'Server error occurred. Please try again later.';
        default:
          return 'Failed to update profile. Please try again.';
      }
      
    } catch (parseError) {
      print('Error parsing response: $parseError');
      return 'Failed to update profile. Server returned: ${response.statusCode}';
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
      final userId = pb.authStore.model!.id;
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
      print('Current user ID: ${pb.authStore.model!.id}');
      final notes = await pb.collection('catatan').getFullList(
            sort: '-created',
            filter: 'user_id = "${pb.authStore.model!.id}" && folder_id = "$folderId"',
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
      print('Fetching recent notes for user ID: ${pb.authStore.model!.id}');
      final response = await pb.collection('catatan').getList(
            page: 1,
            perPage: limit,
            sort: '-updated',
            filter: 'user_id = "${pb.authStore.model!.id}"',
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
      print('Error: User tidak login saat mencoba buat catatan');
      throw Exception('User is not logged in');
    }
    try {
      print('Creating note with title: $title');
      print('Content length: ${content.length} characters');
      print('User ID: ${pb.authStore.model!.id}');
      print('Folder ID: ${folderId ?? 'None (Root folder)'}');
      
      final data = {
        'title': title,
        'content': content,
        'user_id': pb.authStore.model!.id,
      };
      
      if (folderId != null && folderId.isNotEmpty) {
        data['folder_id'] = folderId;
      }
      
      // Debug print the entire data object
      print('Creating note with data: $data');
      
      final result = await pb.collection('catatan').create(body: data);
      print('Note created successfully with ID: ${result.id}');
      return result;
    } catch (e) {
      print('Error creating note: $e');
      // Try to get more detailed error info if available
      if (e.toString().contains('Failed to fetch') || e.toString().contains('NetworkError')) {
        print('Network error detected. Please check your internet connection.');
        throw Exception('Network error. Please check your internet connection and try again.');
      }
      
      throw Exception('Failed to create note: $e');
    }
  }

  Future<RecordModel> updateNote(String id, String title, String content) async {
    if (!isLoggedIn) {
      print('Error: User tidak login saat mencoba update catatan');
      throw Exception('User is not logged in');
    }
    try {
      print('Updating note with ID: $id');
      print('New title: $title');
      print('New content length: ${content.length} characters');
      
      // First check if the note belongs to the current user
      print('Fetching note with ID: $id to check permissions');
      final note = await pb.collection('catatan').getOne(id);
      
      if (note.data['user_id'] != pb.authStore.model!.id) {
        print('Permission error: Note belongs to user ${note.data['user_id']}, but current user is ${pb.authStore.model!.id}');
        throw Exception('You do not have permission to update this note');
      }
      
      // Debug print the update operation
      print('Updating note...');
      final data = {
        'title': title,
        'content': content,
      };
      
      print('Update data: $data');
      
      // Try updating with direct HTTP approach first
      try {
        print('Attempting direct HTTP update...');
        final response = await http.patch(
          Uri.parse('http://127.0.0.1:8090/api/collections/catatan/records/$id'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${pb.authStore.token}',
          },
          body: jsonEncode(data),
        );
        
        print('Direct update response status: ${response.statusCode}');
        print('Direct update response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final updatedData = jsonDecode(response.body);
          print('Note updated successfully via direct HTTP');
          return RecordModel.fromJson(updatedData);
        } else {
          print('Direct HTTP update failed, falling back to SDK method');
          throw Exception('HTTP update failed: Status ${response.statusCode}');
        }
      } catch (directError) {
        print('Direct HTTP update error: $directError');
        print('Falling back to SDK update method...');
        
        // Fallback to SDK method
        final result = await pb.collection('catatan').update(id, body: data);
        print('Note updated successfully via SDK method');
        return result;
      }
    } catch (e) {
      print('Error updating note: $e');
      
      // Try to get more detailed error info
      if (e.toString().contains('Failed to fetch') || e.toString().contains('NetworkError')) {
        print('Network error detected. Please check your internet connection.');
        throw Exception('Network error. Please check your internet connection and try again.');
      }
      
      throw Exception('Failed to update note: $e');
    }
  }

  Future<void> deleteNote(String id) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final note = await pb.collection('catatan').getOne(id);
      if (note.data['user_id'] != pb.authStore.model!.id) {
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
      if (note.data['user_id'] != pb.authStore.model!.id) {
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
      print('Fetching folders for user: ${pb.authStore.model!.id}');
      final folders = await pb.collection('folders').getFullList(
            sort: 'name',
            filter: 'user = "${pb.authStore.model!.id}"',
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
      print('Creating folder: $name with color: $color');
      final result = await pb.collection('folders').create(body: {
        'name': name,
        'color': color,
        'icon': icon,
        'user': pb.authStore.model!.id,
      });
      print('Folder created successfully: ${result.id}');
      return result;
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
      print('Updating folder: $id');
      print('New data - name: $name, color: $color, icon: $icon');
      
      // First check if the folder belongs to the current user
      final folder = await pb.collection('folders').getOne(id);
      if (folder.data['user'] != pb.authStore.model!.id) {
        throw Exception('You do not have permission to update this folder');
      }
      
      final result = await pb.collection('folders').update(id, body: {
        'name': name,
        'color': color,
        'icon': icon,
      });
      print('Folder updated successfully');
      return result;
    } catch (e) {
      print('Error updating folder: $e');
      // Check if it's a permission error
      if (e.toString().contains('403') || e.toString().contains('Only superusers')) {
        throw Exception('Permission denied. Please check your folder permissions in PocketBase.');
      }
      throw Exception('Failed to update folder: $e');
    }
  }

  // 🔥 NEW: Direct folder update method
  Future<RecordModel> updateFolderDirect(String id, String name, String color, String icon) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      print('Updating folder directly: $id');
      
      final response = await http.patch(
        Uri.parse('http://127.0.0.1:8090/api/collections/folders/records/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${pb.authStore.token}',
        },
        body: jsonEncode({
          'name': name,
          'color': color,
          'icon': icon,
        }),
      );
      
      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body);
        return RecordModel.fromJson(updatedData);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error updating folder directly: $e');
      throw Exception('Failed to update folder: $e');
    }
  }

  Future<void> deleteFolder(String id) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      print('Deleting folder: $id');
      
      // First check if the folder belongs to the current user
      final folder = await pb.collection('folders').getOne(id);
      if (folder.data['user'] != pb.authStore.model!.id) {
        throw Exception('You do not have permission to delete this folder');
      }
      
      // Check if there are notes in this folder
      final notesInFolder = await getNotesByFolder(id);
      if (notesInFolder.isNotEmpty) {
        // Option 1: Delete all notes in the folder first
        for (final note in notesInFolder) {
          await deleteNote(note.id);
        }
        print('Deleted ${notesInFolder.length} notes from folder');
      }
      
      await pb.collection('folders').delete(id);
      print('Folder deleted successfully: $id');
    } catch (e) {
      print('Error deleting folder: $e');
      // Check if it's a permission error
      if (e.toString().contains('403') || e.toString().contains('Only superusers')) {
        throw Exception('Permission denied. Please check your folder permissions in PocketBase.');
      }
      throw Exception('Failed to delete folder: $e');
    }
  }

  // 🔥 NEW: Direct folder delete method
  Future<void> deleteFolderDirect(String id) async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      print('Deleting folder directly: $id');
      
      // Delete notes in folder first
      final notesInFolder = await getNotesByFolder(id);
      for (final note in notesInFolder) {
        await deleteNote(note.id);
      }
      
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:8090/api/collections/folders/records/$id'),
        headers: {
          'Authorization': 'Bearer ${pb.authStore.token}',
        },
      );
      
      if (response.statusCode != 204) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
      print('Folder deleted successfully via direct HTTP');
    } catch (e) {
      print('Error deleting folder directly: $e');
      throw Exception('Failed to delete folder: $e');
    }
  }

  Future<List<RecordModel>> getEvents() async {
    if (!isLoggedIn) {
      throw Exception('User is not logged in');
    }
    try {
      final userId = pb.authStore.model!.id;
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
      final userId = pb.authStore.model!.id;
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
        'user_id': pb.authStore.model!.id,
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
      if (event.data['user_id'] != pb.authStore.model!.id) {
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
      if (event.data['user_id'] != pb.authStore.model!.id) {
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
      if (event.data['user_id'] != pb.authStore.model!.id) {
        throw Exception('You do not have permission to access this event');
      }
      return event;
    } catch (e) {
      print('Error getting event: $e');
      throw Exception('Failed to get event: $e');
    }
  }
}