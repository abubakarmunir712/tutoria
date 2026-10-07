import 'package:flutter/material.dart';

import '../tokens.dart';

/// How a subject looks everywhere: its solid accent colour, its pastel tint and its icon.
class SubjectStyle {
  const SubjectStyle(this.accent, this.tint, this.icon);

  final Color accent;
  final Color tint;
  final IconData icon;

  static const _styles = {
    'Mathematics': SubjectStyle(
      TColors.mathsAccent,
      TColors.mathsTint,
      Icons.calculate_rounded,
    ),
    'English Language': SubjectStyle(
      TColors.englishAccent,
      TColors.englishTint,
      Icons.menu_book_rounded,
    ),
    'Science': SubjectStyle(
      TColors.scienceAccent,
      TColors.scienceTint,
      Icons.science_rounded,
    ),
    'Our World and Our People': SubjectStyle(
      TColors.worldAccent,
      TColors.worldTint,
      Icons.public_rounded,
    ),
    'Social Studies': SubjectStyle(
      TColors.socialAccent,
      TColors.socialTint,
      Icons.groups_rounded,
    ),
    'Computing': SubjectStyle(
      TColors.computingAccent,
      TColors.computingTint,
      Icons.computer_rounded,
    ),
  };

  static const _fallback = SubjectStyle(
    TColors.blue600,
    TColors.blue100,
    Icons.school_rounded,
  );

  static SubjectStyle of(String subject) => _styles[subject] ?? _fallback;

  /// Short name for tight spaces ("English", "Our World").
  static String shortName(String subject) => switch (subject) {
    'English Language' => 'English',
    'Our World and Our People' => 'Our World',
    _ => subject,
  };
}
