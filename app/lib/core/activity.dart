import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// What a learner has done on this phone: the basis of "Continue learning", the question count
/// and the streak. It is local until progress is tracked on the server.
@immutable
class LearnerActivity {
  const LearnerActivity({
    this.lastSubject,
    this.lastTopic,
    this.lastAt,
    this.questions = 0,
    this.bySubject = const {},
    this.days = const [],
  });

  factory LearnerActivity.fromJson(Map<String, dynamic> json) =>
      LearnerActivity(
        lastSubject: json['lastSubject'] as String?,
        lastTopic: json['lastTopic'] as String?,
        lastAt: DateTime.tryParse(json['lastAt'] as String? ?? ''),
        questions: json['questions'] as int? ?? 0,
        bySubject: ((json['bySubject'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k as String, v as int),
        ),
        days: ((json['days'] as List?) ?? const []).cast<String>(),
      );

  static const empty = LearnerActivity();

  final String? lastSubject;

  /// The topic last opened from the topic list; null when the child just typed a question.
  final String? lastTopic;
  final DateTime? lastAt;
  final int questions;
  final Map<String, int> bySubject;

  /// Calendar days (yyyy-MM-dd) with any activity, oldest first.
  final List<String> days;

  bool get hasActivity => lastSubject != null;

  /// Consecutive days up to today (or up to yesterday, so the streak isn't lost before the
  /// child has had a chance to study today).
  int streakAt(DateTime now) {
    final set = days.toSet();
    var day = DateTime(now.year, now.month, now.day);
    if (!set.contains(dayKey(day))) day = day.subtract(const Duration(days: 1));
    // Step by calendar day, not by 24 hours, so a clock change can't skip or repeat a day.
    var streak = 0;
    while (set.contains(dayKey(day))) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  LearnerActivity afterQuestion({
    required String subject,
    String? topic,
    required DateTime now,
  }) {
    final today = dayKey(now);
    final nextDays = days.contains(today) ? days : [...days, today];
    return LearnerActivity(
      lastSubject: subject,
      lastTopic: topic,
      lastAt: now,
      questions: questions + 1,
      bySubject: {...bySubject, subject: (bySubject[subject] ?? 0) + 1},
      days: nextDays.length > 120
          ? nextDays.sublist(nextDays.length - 120)
          : nextDays,
    );
  }

  Map<String, dynamic> toJson() => {
    'lastSubject': lastSubject,
    'lastTopic': lastTopic,
    'lastAt': lastAt?.toIso8601String(),
    'questions': questions,
    'bySubject': bySubject,
    'days': days,
  };
}

/// Remembers each learner's activity on this phone and tells screens when it changes.
class ActivityTracker extends ChangeNotifier {
  final _cache = <String, LearnerActivity>{};
  final _loading = <String>{};

  static String _key(String learnerId) => 'activity.$learnerId';

  /// The learner's activity so far; loads from storage the first time it is asked for.
  LearnerActivity of(String learnerId) {
    final cached = _cache[learnerId];
    if (cached != null) return cached;
    if (_loading.add(learnerId)) _load(learnerId);
    return LearnerActivity.empty;
  }

  Future<void> _load(String learnerId) async {
    var loaded = LearnerActivity.empty;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(learnerId));
      if (raw != null) {
        loaded = LearnerActivity.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Unreadable or unavailable storage just means a fresh start.
    }
    _cache.putIfAbsent(learnerId, () => loaded);
    _loading.remove(learnerId);
    notifyListeners();
  }

  Future<void> record(
    String learnerId, {
    required String subject,
    String? topic,
    DateTime? now,
  }) async {
    // Make sure earlier history is in before adding to it.
    if (!_cache.containsKey(learnerId)) await _load(learnerId);
    final updated = (_cache[learnerId] ?? LearnerActivity.empty).afterQuestion(
      subject: subject,
      topic: topic,
      now: now ?? DateTime.now(),
    );
    _cache[learnerId] = updated;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(learnerId), jsonEncode(updated.toJson()));
    } catch (_) {
      // Not being able to save must never get in the way of asking a question.
    }
  }
}
