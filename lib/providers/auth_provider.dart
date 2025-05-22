import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  String? _token;
  String? _userId;

  bool get isLoggedIn => _token != null && !JwtDecoder.isExpired(_token!);

  String? get token => _token;

  String? get userId => _userId;

  Future<void> login(String username, String password) async {
    try {
      final token = await _apiService.login(username, password);
      debugPrint("AuthProvider: Login token received");
      _token = token;
      await _authService.saveToken(token);
      final decoded = JwtDecoder.decode(token);
      _userId = decoded['sub']?.toString();
      debugPrint("AuthProvider: Decoded user_id: $_userId");
      notifyListeners();
    } catch (e) {
      debugPrint("AuthProvider: Login error: $e");
      rethrow;
    }
  }

  Future<void> register(String username, String email, String password) async {
    try {
      await _apiService.register(username, email, password);
      debugPrint("AuthProvider: User registered with username: $username");
      // Автоматически логиним пользователя после регистрации
      final token = await _apiService.login(username, password);
      debugPrint("AuthProvider: Auto-login token received");
      _token = token;
      await _authService.saveToken(token);
      final decoded = JwtDecoder.decode(token);
      _userId = decoded['sub']?.toString();
      debugPrint("AuthProvider: Decoded user_id: $_userId");
      notifyListeners();
    } catch (e) {
      debugPrint("AuthProvider: Register error: $e");
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    await _authService.clearToken();
    debugPrint("AuthProvider: Logged out, token and userId cleared");
    notifyListeners();
  }

  Future<void> loadToken() async {
    _token = await _authService.getToken();
    if (_token != null) {
      try {
        if (JwtDecoder.isExpired(_token!)) {
          debugPrint("AuthProvider: Loaded token is expired, clearing");
          _token = null;
          _userId = null;
          await _authService.clearToken();
        } else {
          final decoded = JwtDecoder.decode(_token!);
          _userId = decoded['sub']?.toString();
          debugPrint("AuthProvider: Loaded token with user_id: $_userId");
        }
      } catch (e) {
        debugPrint("AuthProvider: Invalid token, clearing: $e");
        _token = null;
        _userId = null;
        await _authService.clearToken();
      }
    } else {
      debugPrint("AuthProvider: No token found in storage");
    }
    notifyListeners();
  }
}
