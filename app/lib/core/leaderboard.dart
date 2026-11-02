import 'package:flutter/foundation.dart';

/// One row of the class leaderboard: a first name and initial, never anything more.
@immutable
class BoardRow {
  const BoardRow({
    required this.rank,
    required this.name,
    required this.xp,
    required this.isYou,
  });

  factory BoardRow.fromJson(Map<String, dynamic> json) => BoardRow(
    rank: json['rank'] as int,
    name: json['name'] as String,
    xp: json['xp'] as int,
    isYou: json['isYou'] as bool? ?? false,
  );

  final int rank;
  final String name;
  final int xp;
  final bool isYou;
}

/// This week's XP board for a learner's class.
@immutable
class Leaderboard {
  const Leaderboard({required this.top, this.you, this.hidden = false});

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
    top: ((json['top'] as List?) ?? const [])
        .map((r) => BoardRow.fromJson(r as Map<String, dynamic>))
        .toList(),
    you: json['you'] is Map<String, dynamic>
        ? BoardRow.fromJson(json['you'] as Map<String, dynamic>)
        : null,
    hidden: json['hidden'] as bool? ?? false,
  );

  final List<BoardRow> top;

  /// The learner's own row when they are below the top ten.
  final BoardRow? you;

  /// The learner chose to be left off the board.
  final bool hidden;
}
