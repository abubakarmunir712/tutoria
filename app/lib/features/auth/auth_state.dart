import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/secure_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Who is signed in, and their learners. Screens read this for the current user and call its
/// methods to change learners, so everything shown stays in step with the server.
class AuthState extends ChangeNotifier {
  AuthState({required this.api}) {
    api.onSessionExpired = _sessionExpired;
  }

  final ApiClient api;
  AuthStatus status = AuthStatus.unknown;
  Me? me;
  String? error;
  bool isLoading = false;

  /// Set when signed in but the profile could not be loaded (offline, server down).
  bool profileFailed = false;

  Future<void> bootstrap() async {
    try {
      final token = await SecureStorage.instance.accessToken.timeout(
        const Duration(seconds: 5),
      );
      status = token == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
    if (status == AuthStatus.authenticated) await refreshMe();
  }

  /// Loads the signed-in user. A refused session sends them back to sign in; a network failure
  /// keeps them signed in and lets the screen offer a retry.
  Future<void> refreshMe() async {
    try {
      me = await api.getMe();
      profileFailed = false;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 404) {
        await logout();
        return;
      }
      profileFailed = true;
    } catch (_) {
      profileFailed = true;
    }
    notifyListeners();
  }

  Future<bool> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) => _run(
    () => api.signup(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      role: role,
    ),
  );

  Future<bool> login({required String identifier, required String password}) =>
      _run(() => api.login(identifier: identifier, password: password));

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
      me = await api.getMe();
      profileFailed = false;
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

  // --- Learners (a parent's children, or the student themselves)

  /// Adds a child and returns them, or null with [error] set.
  Future<Learner?> addLearner({
    required String name,
    required String grade,
    String? schoolType,
  }) => _change(
    () => api.createLearner(name: name, grade: grade, schoolType: schoolType),
  );

  Future<Learner?> editLearner(
    String id, {
    String? name,
    String? grade,
    String? schoolType,
  }) => _change(
    () =>
        api.updateLearner(id, name: name, grade: grade, schoolType: schoolType),
  );

  Future<Learner?> chooseSubjects(String learnerId, List<String> subjectIds) =>
      _change(() => api.setSubjects(learnerId, subjectIds));

  Future<bool> removeLearner(String id) async =>
      await _change(() async {
        await api.deleteLearner(id);
        return const Learner(id: '', name: '');
      }) !=
      null;

  Future<Learner?> _change(Future<Learner> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final learner = await action();
      me = await api.getMe();
      return learner;
    } on ApiException catch (e) {
      error = e.message;
      return null;
    } catch (_) {
      error = 'Something went wrong. Check your connection.';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Learner? learnerById(String id) {
    for (final l in me?.learners ?? const <Learner>[]) {
      if (l.id == id) return l;
    }
    return null;
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void _sessionExpired() {
    if (status == AuthStatus.authenticated) logout();
  }

  Future<void> logout() async {
    await SecureStorage.instance.clear();
    me = null;
    profileFailed = false;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// For tests: put the state straight into a signed-in (or out) condition.
  @visibleForTesting
  void debugSet({AuthStatus? status, Me? me}) {
    if (status != null) this.status = status;
    this.me = me;
    notifyListeners();
  }
}
