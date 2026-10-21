import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design/design.dart';

/// Each learner's profile picture, kept on this phone (like their activity) until the server
/// stores profiles. Pictures are small (the picker scales them down), so they live in
/// preferences as base64 rather than needing a file location.
class LearnerPhotos extends ChangeNotifier {
  static const _key = 'learner.photos';
  final _photos = <String, Uint8List>{};
  bool _loaded = false;

  /// The learner's picture, or null if they have none (the initials show instead). Loads from
  /// storage the first time it is asked for.
  Uint8List? of(String learnerId) {
    if (!_loaded) {
      _loaded = true;
      _load();
    }
    return _photos[learnerId];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final stored = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in stored.entries) {
          _photos.putIfAbsent(e.key, () => base64Decode(e.value as String));
        }
      }
    } catch (_) {
      // Unreadable or unavailable storage just means no pictures yet.
    }
    notifyListeners();
  }

  Future<void> set(String learnerId, Uint8List bytes) async {
    _photos[learnerId] = bytes;
    notifyListeners();
    await _save();
  }

  Future<void> remove(String learnerId) async {
    if (_photos.remove(learnerId) == null) return;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_photos.map((k, v) => MapEntry(k, base64Encode(v)))),
      );
    } catch (_) {
      // The picture still shows for this session; it just won't survive a restart.
    }
  }
}

/// A learner's avatar: their picture if they have one, otherwise their initials.
class LearnerAvatar extends StatelessWidget {
  const LearnerAvatar({
    super.key,
    required this.learnerId,
    required this.name,
    this.size = 48,
  });

  final String? learnerId;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = learnerId == null
        ? null
        : context.watch<LearnerPhotos>().of(learnerId!);
    return Avatar(name: name, size: size, photo: photo);
  }
}
