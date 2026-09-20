import 'package:flutter/foundation.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends ChangeNotifier {
  AuthState({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;
  AuthStatus status = AuthStatus.unknown;
  String? error;
  bool isLoading = false;

  Future<void> bootstrap() async {
    try {
      final token = await SecureStorage.instance.accessToken.timeout(const Duration(seconds: 5));
      status = token == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> signup({
    required String email,
    required String phone,
    required String password,
  }) => _run(() => _api.signup(email: email, phone: phone, password: password));

  Future<bool> login({
    required String identifier,
    required String password,
  }) => _run(() => _api.login(identifier: identifier, password: password));

  Future<bool> _run(Future<Map<String, dynamic>> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await action();
      await SecureStorage.instance.saveTokens(
        accessToken: result['accessToken'] as String,
        refreshToken: result['refreshToken'] as String,
      );
      status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Something went wrong. Check your connection.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await SecureStorage.instance.clear();
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
