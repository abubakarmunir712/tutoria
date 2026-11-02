import 'dart:async';

import 'package:flutter/foundation.dart';

import 'activity.dart';
import 'api_client.dart';

/// A badge a learner can earn, and whether (and when) they have.
@immutable
class BadgeInfo {
  const BadgeInfo({
    required this.code,
    required this.name,
    required this.description,
    required this.earned,
    this.earnedAt,
  });

  factory BadgeInfo.fromJson(Map<String, dynamic> json) => BadgeInfo(
    code: json['code'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    earned: json['earned'] as bool? ?? true,
    earnedAt: DateTime.tryParse(json['earnedAt'] as String? ?? ''),
  );

  final String code;
  final String name;
  final String description;
  final bool earned;
  final DateTime? earnedAt;
}

/// One day of the last week: how many things the learner did and the XP they earned.
@immutable
class WeekDay {
  const WeekDay({required this.day, required this.count, required this.xp});

  factory WeekDay.fromJson(Map<String, dynamic> json) => WeekDay(
    day: json['day'] as String,
    count: json['count'] as int,
    xp: json['xp'] as int,
  );

  /// yyyy-MM-dd (UTC, which is the learners' day in Ghana).
  final String day;
  final int count;
  final int xp;

  /// 1 = Monday ... 7 = Sunday.
  int get weekday => DateTime.parse('${day}T00:00:00Z').weekday;
}

@immutable
class RecentTopic {
  const RecentTopic({required this.subject, required this.topic, this.at});

  factory RecentTopic.fromJson(Map<String, dynamic> json) => RecentTopic(
    subject: json['subject'] as String,
    topic: json['topic'] as String,
    at: DateTime.tryParse(json['at'] as String? ?? ''),
  );

  final String subject;
  final String topic;
  final DateTime? at;
}

/// How one learner is doing, as kept by the server: the same figures a parent sees.
@immutable
class Progress {
  const Progress({
    required this.studentId,
    this.xp = 0,
    this.level = 1,
    this.levelStartXp = 0,
    this.nextLevelXp = 50,
    this.streak = 0,
    this.bestStreak = 0,
    this.questions = 0,
    this.photos = 0,
    this.voices = 0,
    this.quizzes = 0,
    this.assignments = 0,
    this.lastSubject,
    this.lastTopic,
    this.lastActiveAt,
    this.bySubject = const {},
    this.days = const [],
    this.week = const [],
    this.questionsThisWeek = 0,
    this.xpThisWeek = 0,
    this.recentTopics = const [],
    this.badges = const [],
  });

  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
    studentId: json['studentId'] as String,
    xp: json['xp'] as int? ?? 0,
    level: json['level'] as int? ?? 1,
    levelStartXp: json['levelStartXp'] as int? ?? 0,
    nextLevelXp: json['nextLevelXp'] as int? ?? 50,
    streak: json['streak'] as int? ?? 0,
    bestStreak: json['bestStreak'] as int? ?? 0,
    questions: json['questions'] as int? ?? 0,
    photos: json['photos'] as int? ?? 0,
    voices: json['voices'] as int? ?? 0,
    quizzes: json['quizzes'] as int? ?? 0,
    assignments: json['assignments'] as int? ?? 0,
    lastSubject: json['lastSubject'] as String?,
    lastTopic: json['lastTopic'] as String?,
    lastActiveAt: DateTime.tryParse(json['lastActiveAt'] as String? ?? ''),
    bySubject: ((json['bySubject'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k as String, v as int),
    ),
    days: ((json['days'] as List?) ?? const []).cast<String>(),
    week: ((json['week'] as List?) ?? const [])
        .map((d) => WeekDay.fromJson(d as Map<String, dynamic>))
        .toList(),
    questionsThisWeek: json['questionsThisWeek'] as int? ?? 0,
    xpThisWeek: json['xpThisWeek'] as int? ?? 0,
    recentTopics: ((json['recentTopics'] as List?) ?? const [])
        .map((t) => RecentTopic.fromJson(t as Map<String, dynamic>))
        .toList(),
    badges: ((json['badges'] as List?) ?? const [])
        .map((b) => BadgeInfo.fromJson(b as Map<String, dynamic>))
        .toList(),
  );

  final String studentId;
  final int xp;
  final int level;
  final int levelStartXp;
  final int nextLevelXp;

  /// Consecutive days up to today (or yesterday, so it isn't lost before today's study).
  final int streak;
  final int bestStreak;
  final int questions;
  final int photos;
  final int voices;
  final int quizzes;
  final int assignments;
  final String? lastSubject;
  final String? lastTopic;
  final DateTime? lastActiveAt;
  final Map<String, int> bySubject;

  /// Days (yyyy-MM-dd) with any activity in the last 120 days, oldest first.
  final List<String> days;
  final List<WeekDay> week;
  final int questionsThisWeek;
  final int xpThisWeek;
  final List<RecentTopic> recentTopics;
  final List<BadgeInfo> badges;

  int get xpIntoLevel => xp - levelStartXp;
  int get xpForLevel => nextLevelXp - levelStartXp;
  int get xpToNextLevel => nextLevelXp - xp;

  /// 0..1 through the current level.
  double get levelFraction =>
      xpForLevel <= 0 ? 0 : (xpIntoLevel / xpForLevel).clamp(0.0, 1.0);

  List<BadgeInfo> get earnedBadges => badges.where((b) => b.earned).toList();

  bool get hasActivity => questions > 0 || quizzes > 0 || assignments > 0;
}

/// A child in the parent's list: their name and class with how they are doing.
@immutable
class ChildProgress {
  const ChildProgress({required this.name, this.grade, required this.progress});

  factory ChildProgress.fromJson(Map<String, dynamic> json) => ChildProgress(
    name: json['name'] as String,
    grade: json['grade'] as String?,
    progress: Progress.fromJson(json),
  );

  final String name;
  final String? grade;
  final Progress progress;
}

/// What one question earned, as reported by the server with the answer.
@immutable
class Award {
  const Award({
    required this.xpGained,
    required this.xp,
    required this.level,
    required this.leveledUp,
    required this.streak,
    this.firstOfDay = 0,
    this.streakBonus = 0,
    this.newBadges = const [],
  });

  factory Award.fromJson(Map<String, dynamic> json) {
    final award = (json['award'] as Map?) ?? const {};
    return Award(
      xpGained: json['xpGained'] as int? ?? 0,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      leveledUp: json['leveledUp'] as bool? ?? false,
      streak: json['streak'] as int? ?? 0,
      firstOfDay: award['firstOfDay'] as int? ?? 0,
      streakBonus: award['streak'] as int? ?? 0,
      newBadges: ((json['newBadges'] as List?) ?? const [])
          .map(
            (b) => BadgeInfo.fromJson({
              ...(b as Map<String, dynamic>),
              'earned': true,
            }),
          )
          .toList(),
    );
  }

  final int xpGained;
  final int xp;
  final int level;
  final bool leveledUp;
  final int streak;
  final int firstOfDay;
  final int streakBonus;
  final List<BadgeInfo> newBadges;

  /// Worth interrupting the child for: XP, a level or a badge.
  bool get isNews => xpGained > 0 || leveledUp || newBadges.isNotEmpty;
}

/// Progress as the server has it, kept for the screens that show it.
///
/// Whatever the server knows replaces the on-phone [ActivityTracker] record, so the home screen,
/// the Progress tab and a parent's dashboard all agree.
class ProgressStore extends ChangeNotifier {
  ProgressStore({required this.api, required this.activity});

  final ApiClient api;
  final ActivityTracker activity;

  final _cache = <String, Progress>{};
  final _loading = <String>{};
  final _failed = <String>{};
  var _allLoading = false;

  /// The learner's progress; null until it has loaded. The first ask starts the load.
  Progress? of(String learnerId) {
    final cached = _cache[learnerId];
    if (cached == null &&
        !_failed.contains(learnerId) &&
        _loading.add(learnerId)) {
      unawaited(_fetch(learnerId));
    }
    return cached;
  }

  /// What is known about a learner so far, without starting a load.
  Progress? peek(String learnerId) => _cache[learnerId];

  Future<void> _fetch(String learnerId) async {
    try {
      _store(await api.getProgress(learnerId));
    } catch (_) {
      // Progress is a nicety: a failed load leaves the screens as they were.
      _failed.add(learnerId);
    } finally {
      _loading.remove(learnerId);
      notifyListeners();
    }
  }

  void _store(Progress p) {
    _cache[p.studentId] = p;
    _failed.remove(p.studentId);
    // Only a learner the server has activity for overrides the phone's own record, so history
    // kept on the phone before progress moved to the server is not wiped by an empty reply.
    if (p.hasActivity) unawaited(activity.replaceWith(p.studentId, p));
  }

  /// Fetch one learner again (after a question, or on pull to refresh).
  Future<void> refresh(String learnerId) async {
    try {
      _store(await api.getProgress(learnerId));
    } catch (_) {
      // Keep showing what we had.
    }
    notifyListeners();
  }

  /// Fetch every child at once for the parent dashboard.
  Future<void> refreshAll() async {
    if (_allLoading) return;
    _allLoading = true;
    try {
      for (final c in await api.getAllProgress()) {
        _store(c.progress);
      }
    } catch (_) {
      // Keep showing what we had.
    } finally {
      _allLoading = false;
      notifyListeners();
    }
  }
}
