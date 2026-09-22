import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';
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

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  Future<Map<String, dynamic>> _decode(http.Response res) async {
    final body = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
        res.statusCode,
        decoded['message']?.toString() ?? 'Request failed',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> signup({
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await _client.post(
      _uri('/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'phone': phone, 'password': password}),
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

  Future<Map<String, dynamic>> getProfile() async {
    final token = await SecureStorage.instance.accessToken;
    final res = await _client.get(
      _uri('/me/profile'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateGrade(String grade) async {
    final token = await SecureStorage.instance.accessToken;
    final res = await _client.patch(
      _uri('/me/profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'grade': grade}),
    );
    return _decode(res);
  }

  Future<List<dynamic>> listSubjects() async {
    final token = await SecureStorage.instance.accessToken;
    final res = await _client.get(
      _uri('/me/subjects'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = res.body.isEmpty ? '[]' : res.body;
    if (res.statusCode >= 400) {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      throw ApiException(
        res.statusCode,
        decoded['message']?.toString() ?? 'Request failed',
      );
    }
    return jsonDecode(body) as List<dynamic>;
  }

  Future<ChatResponse> askQuestion({
    required String question,
    String? grade,
    String? subject,
    List<Map<String, String>>? history,
  }) async {
    final token = await SecureStorage.instance.accessToken;
    final res = await _client.post(
      _uri('/chat/ask'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'question': question,
        'grade': grade,
        'subject': subject,
        'history': history ?? [],
      }),
    );
    return ChatResponse.fromJson(await _decode(res));
  }

  Future<ChatResponse> askWithImage({
    required File image,
    String? grade,
    String? subject,
  }) async {
    final token = await SecureStorage.instance.accessToken;
    final request = http.MultipartRequest('POST', _uri('/chat/ask-image'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('image', image.path));
    if (grade != null) request.fields['grade'] = grade;
    if (subject != null) request.fields['subject'] = subject;

    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    return ChatResponse.fromJson(await _decode(res));
  }
}
