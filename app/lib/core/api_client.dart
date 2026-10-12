import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'models.dart';
import 'secure_storage.dart';

class ChatCitation {
  ChatCitation({
    required this.indicatorCode,
    required this.strand,
    required this.substrand,
    required this.images,
  });

  factory ChatCitation.fromJson(Map<String, dynamic> json) => ChatCitation(
    indicatorCode: json['indicator_code'] as String,
    strand: json['strand'] as String,
    substrand: json['substrand'] as String,
    images: (json['images'] as List).cast<String>(),
  );

  final String indicatorCode;
  final String strand;
  final String substrand;
  final List<String> images;
}

class ChatResponse {
  ChatResponse({required this.answer, required this.citations});

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
    answer: json['answer'] as String,
    citations: (json['citations'] as List)
        .map((c) => ChatCitation.fromJson(c as Map<String, dynamic>))
        .toList(),
  );

  final String answer;
  final List<ChatCitation> citations;
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Called when the session can no longer be renewed (the refresh token was refused), so the
  /// app can send the user back to sign in.
  void Function()? onSessionExpired;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);

  dynamic _decodeBody(http.Response res) {
    final body = res.body.isEmpty ? 'null' : res.body;
    final decoded = jsonDecode(body);
    if (res.statusCode >= 400) {
      final message = decoded is Map ? decoded['message'] : null;
      throw ApiException(
        res.statusCode,
        (message is List ? message.join(', ') : message)?.toString() ??
            'Request failed',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _decode(http.Response res) async =>
      (_decodeBody(res) ?? <String, dynamic>{}) as Map<String, dynamic>;

  /// Sends a request with the access token, and if the server says the token has expired (they
  /// last 15 minutes) renews it once with the refresh token and tries again.
  Future<http.Response> _authed(
    Future<http.Response> Function(String token) send,
  ) async {
    final storage = SecureStorage.instance;
    var res = await send(await storage.accessToken ?? '');
    if (res.statusCode == 401 && await _refreshSession()) {
      res = await send(await storage.accessToken ?? '');
    }
    if (res.statusCode == 401) onSessionExpired?.call();
    return res;
  }

  Future<bool> _refreshSession() async {
    final refresh = await SecureStorage.instance.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _client.post(
        _uri('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (res.statusCode >= 400) return false;
      final tokens = jsonDecode(res.body) as Map<String, dynamic>;
      await SecureStorage.instance.saveTokens(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _json(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // --- Accounts

  Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    final res = await _client.post(
      _uri('/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role.api,
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _client.post(
      _uri('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    return _decode(res);
  }

  /// The signed-in user and their learners (a parent's children, or a student's own profile).
  Future<Me> getMe() async {
    final res = await _authed(
      (t) => _client.get(_uri('/me'), headers: _json(t)),
    );
    return Me.fromJson(await _decode(res));
  }

  /// Subjects taught in a class's phase.
  Future<List<Subject>> listSubjects({required String grade}) async {
    final res = await _authed(
      (t) => _client.get(
        _uri('/me/subjects', {'grade': grade}),
        headers: _json(t),
      ),
    );
    return (_decodeBody(res) as List)
        .map((s) => Subject.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<Learner> createLearner({
    required String name,
    required String grade,
    String? schoolType,
  }) async {
    final res = await _authed(
      (t) => _client.post(
        _uri('/me/students'),
        headers: _json(t),
        body: jsonEncode({
          'name': name,
          'grade': grade,
          'schoolType': ?schoolType,
        }),
      ),
    );
    return Learner.fromJson(await _decode(res));
  }

  Future<Learner> updateLearner(
    String id, {
    String? name,
    String? grade,
    String? schoolType,
  }) async {
    final res = await _authed(
      (t) => _client.patch(
        _uri('/me/students/$id'),
        headers: _json(t),
        body: jsonEncode({
          'name': ?name,
          'grade': ?grade,
          'schoolType': ?schoolType,
        }),
      ),
    );
    return Learner.fromJson(await _decode(res));
  }

  Future<void> deleteLearner(String id) async {
    final res = await _authed(
      (t) => _client.delete(_uri('/me/students/$id'), headers: _json(t)),
    );
    _decodeBody(res);
  }

  Future<Learner> setSubjects(String learnerId, List<String> subjectIds) async {
    final res = await _authed(
      (t) => _client.put(
        _uri('/me/students/$learnerId/subjects'),
        headers: _json(t),
        body: jsonEncode({'subjectIds': subjectIds}),
      ),
    );
    return Learner.fromJson(await _decode(res));
  }

  // --- Curriculum and tutoring

  /// The curriculum's strands and topics for a class and subject, in curriculum order.
  Future<List<CurriculumStrand>> topics({
    required String grade,
    required String subject,
  }) async {
    final res = await _authed(
      (t) => _client.get(
        _uri('/curriculum/topics', {'grade': grade, 'subject': subject}),
        headers: _json(t),
      ),
    );
    final body = await _decode(res);
    return (body['strands'] as List)
        .map((s) => CurriculumStrand.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<ChatResponse> askQuestion({
    required String question,
    String? grade,
    String? subject,
    List<Map<String, String>>? history,
  }) async {
    final res = await _authed(
      (token) => _client.post(
        _uri('/chat/ask'),
        headers: _json(token),
        body: jsonEncode({
          'question': question,
          'grade': grade,
          'subject': subject,
          'history': history ?? [],
        }),
      ),
    );
    return ChatResponse.fromJson(await _decode(res));
  }

  Future<ChatResponse> askWithImage({
    required File image,
    String? grade,
    String? subject,
    List<Map<String, String>>? history,
  }) async {
    final res = await _authed((token) async {
      // A multipart request can only be sent once, so each attempt builds its own.
      final request = http.MultipartRequest('POST', _uri('/chat/ask-image'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('image', image.path));
      if (grade != null) request.fields['grade'] = grade;
      if (subject != null) request.fields['subject'] = subject;
      // Multipart forms carry strings only, so prior turns go as a JSON string.
      if (history != null && history.isNotEmpty) {
        request.fields['history'] = jsonEncode(history);
      }
      return http.Response.fromStream(await _client.send(request));
    });
    return ChatResponse.fromJson(await _decode(res));
  }

  /// A spoken question as text. The caller shows it and sends it like a typed message.
  Future<String> transcribeAudio(File audio) async {
    final res = await _authed((token) async {
      final request = http.MultipartRequest('POST', _uri('/chat/transcribe'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('audio', audio.path));
      return http.Response.fromStream(await _client.send(request));
    });
    final body = await _decode(res);
    return (body['text'] as String? ?? '').trim();
  }

  /// A tutor reply as spoken audio (WAV).
  Future<Uint8List> speak(String text) async {
    final res = await _authed(
      (token) => _client.post(
        _uri('/chat/speak'),
        headers: _json(token),
        body: jsonEncode({'text': text}),
      ),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, 'Could not read the answer aloud.');
    }
    return res.bodyBytes;
  }
}
