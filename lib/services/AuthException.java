package services;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/announcement.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class ApiService {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'https://pet-backend-451084843622.europe-west4.run.app';

  // Получение токена из SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    debugPrint('ApiService: Retrieved token: ${token != null ? 'present' : 'null'}');
    return token;
  }

  // Сохранение токена в SharedPreferences
  Future<void> _setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    debugPrint('ApiService: Saved token');
  }

  // Очистка токена (для выхода из аккаунта)
  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    debugPrint('ApiService: Token cleared');
  }

  // Извлечение чистого сообщения об ошибке
  String extractErrorMessage(dynamic error) {
    if (error is AuthException) {
      return 'Требуется авторизация';
    }
    try {
      final errorString = error.toString().replaceFirst('Exception: ', '');
      try {
        final errorJson = jsonDecode(errorString);
        if (errorJson is Map<String, dynamic>) {
          if (errorJson['detail'] is Map<String, dynamic>) {
            return errorJson['detail']['message']?.toString() ?? 'Произошла ошибка';
          }
          return errorJson['detail']?.toString() ?? 'Произошла ошибка';
        }
        return errorString
            .replaceFirst('Validate error: ', '')
            .replaceFirst('Create error: ', '')
            .replaceFirst('Search error: ', '')
            .replaceFirst('Exception: ', '') ?? 'Произошла ошибка';
      } catch (_) {
        return errorString
            .replaceFirst('Validate error: ', '')
            .replaceFirst('Create error: ', '')
            .replaceFirst('Search error: ', '')
            .replaceFirst('Exception: ', '') ?? 'Произошла ошибка';
      }
    } catch (e) {
      debugPrint('ApiService: Error extracting message: $e');
      return 'Произошла ошибка';
    }
  }

  // Добавление заголовков с токеном
  Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await _getToken();
      if (token == null) {
        debugPrint('ApiService: No token found, throwing AuthException');
        throw AuthException('Требуется авторизация');
      }
      headers['Authorization'] = 'Bearer $token';
      debugPrint('ApiService: Added Authorization header: Bearer $token');
    }
    return headers;
  }

  Future<String> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/users/token');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': username,
        'password': password,
      },
    );
    debugPrint('ApiService: Login - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'] as String;
      await _setToken(token);
      return token;
    } else {
      throw Exception(response.body);
    }
  }

  Future<void> register(String username, String email, String password) async {
    final uri = Uri.parse('$baseUrl/users/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    debugPrint('ApiService: Register - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else {
      throw Exception(response.body);
    }
  }

  Future<List<Message>> getChat(int announcementId) async {
    final uri = Uri.parse('$baseUrl/chat/$announcementId');
    final headers = await _getHeaders(requiresAuth: true);
    final response = await http.get(uri, headers: headers);
    debugPrint('ApiService: GetChat - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception(response.body);
    }
  }

  Future<void> sendMessage(int announcementId, String message) async {
    final uri = Uri.parse('$baseUrl/chat/$announcementId');
    final headers = await _getHeaders(requiresAuth: true);
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    final response = await http.post(
      uri,
      headers: headers,
      body: {
        'message': message,
      },
    );
    debugPrint('ApiService: SendMessage - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  Future<void> markMessagesAsRead(int announcementId) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('No token found');

      final response = await http.post(
        Uri.parse('$baseUrl/chat/$announcementId/mark_read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark messages as read: ${response.body}');
      }
      debugPrint('ApiService: Messages marked as read for announcement $announcementId');
    } catch (e) {
      debugPrint('ApiService: Mark messages as read error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> validateImages({
    required File image,
    String? previousType,
  }) async {
    final uri = Uri.parse('$baseUrl/validate_images');
    var request = http.MultipartRequest('POST', uri);

    final headers = await _getHeaders(requiresAuth: true);
    request.headers.addAll(headers);
    request.headers.remove('Content-Type');

    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    if (previousType != null) {
      request.fields['previous_type'] = previousType;
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint('ApiService: ValidateImages - Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      } else {
        throw Exception(responseBody);
      }
    } catch (e) {
      debugPrint('ApiService: ValidateImages - Error: $e');
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<Announcement> createAnnouncement({
    required String animalType,
    required String gender,
    String? name,
    int? age,
    String? breed,
    String? color,
    String? keywords,
    String? description,
    List<File>? images,
    String? location,
  }) async {
    final uri = Uri.parse('$baseUrl/create_announcement');
    var request = http.MultipartRequest('POST', uri);

    final headers = await _getHeaders(requiresAuth: true);
    request.headers.addAll(headers);
    request.headers.remove('Content-Type');

    request.fields['animal_type'] = animalType;
    request.fields['gender'] = gender;
    if (name != null) request.fields['name'] = name;
    if (age != null) request.fields['age'] = age.toString();
    if (breed != null) request.fields['breed'] = breed;
    if (color != null) request.fields['color'] = color;
    if (keywords != null) request.fields['keywords'] = keywords;
    if (description != null) request.fields['description'] = description;
    if (location != null) request.fields['location'] = location;

    if (images != null && images.isNotEmpty) {
      for (var image in images) {
        final fileSize = await image.length();
        debugPrint('ApiService: Sending image: ${image.path}, size: $fileSize bytes');
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint('ApiService: CreateAnnouncement - Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return Announcement.fromJson(data);
      } else {
        throw Exception(responseBody);
      }
    } catch (e) {
      debugPrint('ApiService: CreateAnnouncement - Error: $e');
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<Announcement> updateAnnouncement({
    required int announcementId,
    required String animalType,
    required String gender,
    String? name,
    int? age,
    String? breed,
    String? color,
    String? keywords,
    String? description,
    List<File>? images,
    String? location,
  }) async {
    final uri = Uri.parse('$baseUrl/update_announcement/$announcementId');
    var request = http.MultipartRequest('POST', uri);

    final headers = await _getHeaders(requiresAuth: true);
    request.headers.addAll(headers);
    request.headers.remove('Content-Type');

    request.fields['animal_type'] = animalType;
    request.fields['gender'] = gender;
    if (name != null) request.fields['name'] = name;
    if (age != null) request.fields['age'] = age.toString();
    if (breed != null) request.fields['breed'] = breed;
    if (color != null) request.fields['color'] = color;
    if (keywords != null) request.fields['keywords'] = keywords;
    if (description != null) request.fields['description'] = description;
    if (location != null) request.fields['location'] = location;

    if (images != null && images.isNotEmpty) {
      for (var image in images) {
        final fileSize = await image.length();
        debugPrint('ApiService: Sending image: ${image.path}, size: $fileSize bytes');
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint('ApiService: UpdateAnnouncement - Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return Announcement.fromJson(data);
      } else {
        throw Exception(responseBody);
      }
    } catch (e) {
      debugPrint('ApiService: UpdateAnnouncement - Error: $e');
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<List<Map<String, dynamic>>?> searchAnnouncements({
    String? animalType,
    String? gender,
    int? age,
    List<String>? breeds,
    String? color,
    List<String>? keywords,
    List<File>? images,
    String? location,
  }) async {
    final uri = Uri.parse('$baseUrl/search_announcements');
    var request = http.MultipartRequest('POST', uri);

    final headers = await _getHeaders(requiresAuth: true);
    request.headers.addAll(headers);
    request.headers.remove('Content-Type');

    if (animalType != null) request.fields['animal_type'] = animalType;
    if (gender != null) request.fields['gender'] = gender;
    if (age != null) request.fields['age'] = age.toString();
    if (breeds != null && breeds.isNotEmpty) request.fields['breeds'] = breeds.join(',');
    if (color != null) request.fields['color'] = color;
    if (keywords != null && keywords.isNotEmpty) request.fields['keywords'] = keywords.join(',');
    if (location != null) request.fields['location'] = location;

    if (images != null && images.isNotEmpty) {
      for (var image in images) {
        final fileSize = await image.length();
        debugPrint('ApiService: Sending image: ${image.path}, size: $fileSize bytes');
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint('ApiService: SearchAnnouncements - Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        List<Map<String, dynamic>> announcements;
        if (decoded is List) {
          announcements = decoded.cast<Map<String, dynamic>>();
        } else if (decoded is Map<String, dynamic> && decoded.containsKey('announcements')) {
          announcements = (decoded['announcements'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception('Expected a list of announcements, got: $responseBody');
        }
        return announcements;
      } else {
        throw Exception(responseBody);
      }
    } catch (e) {
      debugPrint('ApiService: SearchAnnouncements - Error: $e');
      throw Exception(extractErrorMessage(e));
    }
  }

  Future<void> addFavorite(int announcementId) async {
    final uri = Uri.parse('$baseUrl/favorites');
    final headers = await _getHeaders(requiresAuth: true);
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'announcement_id': announcementId}),
    );
    debugPrint('ApiService: AddFavorite - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  Future<void> removeFavorite(int announcementId) async {
    final uri = Uri.parse('$baseUrl/favorites/$announcementId');
    final headers = await _getHeaders(requiresAuth: true);
    final response = await http.delete(uri, headers: headers);
    debugPrint('ApiService: RemoveFavorite - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final uri = Uri.parse('$baseUrl/favorites');
    final headers = await _getHeaders(requiresAuth: true);
    final response = await http.get(uri, headers: headers);
    debugPrint('ApiService: GetFavorites - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception(response.body);
    }
  }

  Future<List<Announcement>> getMyAnnouncements() async {
    final uri = Uri.parse('$baseUrl/announcements/my');
    final headers = await _getHeaders(requiresAuth: true);
    final response = await http.get(uri, headers: headers);
    debugPrint('ApiService: GetMyAnnouncements - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Announcement.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      debugPrint('ApiService: GetMyAnnouncements - Unauthorized, throwing AuthException');
      throw AuthException('Требуется авторизация');
    } else {
      throw Exception(extractErrorMessage(response.body));
    }
  }

  Future<void> deleteAnnouncement(int announcementId) async {
    final headers = await _getHeaders(requiresAuth: true);
    debugPrint('ApiService: Sending DELETE request with headers: $headers');
    final response = await http.delete(
      Uri.parse('$baseUrl/announcements/$announcementId'),
      headers: headers,
    );

    debugPrint('ApiService: deleteAnnouncement response: status=${response.statusCode}, body=${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to delete announcement: ${response.body}');
    }
  }

  // Новый метод для получения списка чатов пользователя
  Future<List<Map<String, dynamic>>> getUserChats() async {
    final uri = Uri.parse('$baseUrl/chats');
    final headers = await _getHeaders(requiresAuth: true);
    final response = await http.get(uri, headers: headers);
    debugPrint('ApiService: GetUserChats - Status: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception(extractErrorMessage(response.body));
    }
  }
}