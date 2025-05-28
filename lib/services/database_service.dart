import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:your_creative_notebook/models/folder.dart';
import 'package:your_creative_notebook/models/note.dart';

class DatabaseService {
  // Gunakan environment variable atau konfigurasi untuk URL
  final String baseUrl = "http://127.0.0.1:8090/api/collections";

  // Get all folders dengan error handling yang lebih baik
  Future<List<Folder>> getFolders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/folders/records'),
        headers: {'Content-Type': 'application/json'},
      );

      // Detailed logging
      print('Folders Endpoint: $baseUrl/folders/records');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Pastikan struktur JSON sesuai
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        List<dynamic> items = jsonResponse['items'] ?? [];
        
        // Log items sebelum konversi
        print('Raw Folder Items: $items');

        // Konversi menggunakan metode fromPocketBase yang ada
        List<Folder> folders = items.map((folder) {
          try {
            return Folder.fromPocketBase(folder);
          } catch (e) {
            print('Error converting folder: $e');
            print('Problematic folder data: $folder');
            return null;
          }
        }).whereType<Folder>().toList();

        return folders;
      } else {
        // Throw exception dengan pesan detail
        throw Exception('Failed to load folders. Status code: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      // Log error dengan detail
      print('Exception in getFolders: $e');
      
      // Re-throw untuk memungkinkan penanganan di UI
      rethrow;
    }
  }

  // Get notes by folder
  Future<List<Note>> getNotesByFolder(String folderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/catatan/records?filter=(folder_id="$folderId")'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Notes by Folder Endpoint: $baseUrl/catatan/records?filter=(folder_id="$folderId")');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        List<dynamic> items = jsonResponse['items'] ?? [];
        
        List<Note> notes = items.map((note) {
          try {
            return Note.fromPocketBase(note);
          } catch (e) {
            print('Error converting note: $e');
            print('Problematic note data: $note');
            return null;
          }
        }).whereType<Note>().toList();

        return notes;
      } else {
        throw Exception('Failed to load notes. Status code: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      print('Exception in getNotesByFolder: $e');
      rethrow;
    }
  }

  // Get recent notes
  Future<List<Note>> getRecentNotes({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/catatan/records?sort=-updated&perPage=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Recent Notes Endpoint: $baseUrl/catatan/records?sort=-updated&perPage=$limit');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        List<dynamic> items = jsonResponse['items'] ?? [];
        
        List<Note> notes = items.map((note) {
          try {
            return Note.fromPocketBase(note);
          } catch (e) {
            print('Error converting note: $e');
            print('Problematic note data: $note');
            return null;
          }
        }).whereType<Note>().toList();

        return notes;
      } else {
        throw Exception('Failed to load recent notes. Status code: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      print('Exception in getRecentNotes: $e');
      rethrow;
    }
  }

  // Get current username
  Future<String> getCurrentUsername() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/records'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Username Endpoint: $baseUrl/users/records');
      print('Username Response Status: ${response.statusCode}');
      print('Username Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        // Debugging print
        print('Response Keys: ${jsonResponse.keys}');
        print('Items Type: ${jsonResponse['items'].runtimeType}');
        print('Items Length: ${jsonResponse['items']?.length}');

        // Coba ambil username dengan berbagai cara
        if (jsonResponse['items'] != null && jsonResponse['items'].isNotEmpty) {
          var firstUser = jsonResponse['items'][0];
          print('First User Data: $firstUser');

          return firstUser['name'] ?? firstUser['email']?.split('@')[0] ?? 'User';
        }
        
        return 'User';
      } else {
        print('Failed to load user. Status: ${response.statusCode}');
        print('Response Body: ${response.body}');
        return 'User';
      }
    } catch (e) {
      print('Complete Exception in getCurrentUsername: $e');
      return 'User';
    }
  }

  // Create a new note
  Future<Note> createNote(Note note) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/catatan/records'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(note.toPocketBase()),
      );

      print('Create Note Endpoint: $baseUrl/catatan/records');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return Note.fromPocketBase(json.decode(response.body));
      } else {
        throw Exception('Failed to create note. Status code: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      print('Exception in createNote: $e');
      rethrow;
    }
  }

  // Update an existing note
  Future<Note> updateNote(Note note) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/catatan/records/${note.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(note.toPocketBase()),
      );

      print('Update Note Endpoint: $baseUrl/catatan/records/${note.id}');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return Note.fromPocketBase(json.decode(response.body));
      } else {
        throw Exception('Failed to update note. Status code: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      print('Exception in updateNote: $e');
      rethrow;
    }
  }

  // Delete a note
  Future<bool> deleteNote(String noteId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/catatan/records/$noteId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Delete Note Endpoint: $baseUrl/catatan/records/$noteId');
      print('Response Status Code: ${response.statusCode}');

      return response.statusCode == 204;
    } catch (e) {
      print('Exception in deleteNote: $e');
      return false;
    }
  }

  // Create a new folder
  Future<Folder> createFolder(Folder folder) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/folders/records'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(folder.toPocketBase()),
      );

      print('Create Folder Endpoint: $baseUrl/folders/records');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return Folder.fromPocketBase(json.decode(response.body));
      } else {
        throw Exception('Failed to create folder. Status code: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      print('Exception in createFolder: $e');
      rethrow;
    }
  }
}