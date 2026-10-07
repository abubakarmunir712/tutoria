import 'grade_labels.dart';

enum UserRole {
  parent,
  student;

  static UserRole parse(String value) =>
      value == 'PARENT' ? UserRole.parent : UserRole.student;
  String get api => this == UserRole.parent ? 'PARENT' : 'STUDENT';
}

class Subject {
  const Subject({required this.id, required this.name, required this.phase});

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    id: json['id'] as String,
    name: json['name'] as String,
    phase: json['phase'] as String,
  );

  final String id;
  final String name;
  final String phase;
}

/// A learner profile: one of a parent's children, or a student's own.
class Learner {
  const Learner({
    required this.id,
    required this.name,
    this.grade,
    this.schoolType,
    this.subjects = const [],
  });

  factory Learner.fromJson(Map<String, dynamic> json) => Learner(
    id: json['id'] as String,
    name: json['name'] as String,
    grade: json['grade'] as String?,
    schoolType: json['schoolType'] as String?,
    subjects: ((json['enrollments'] as List?) ?? const [])
        .map(
          (e) => Subject.fromJson(
            (e as Map<String, dynamic>)['subject'] as Map<String, dynamic>,
          ),
        )
        .toList(),
  );

  final String id;
  final String name;

  /// Raw grade code ('B5', 'SHS1'); see grade_labels.dart for the names students use.
  final String? grade;
  final String? schoolType;
  final List<Subject> subjects;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
  String get classLabel => grade == null ? 'No class yet' : gradeLabel(grade);
}

/// The signed-in user and their learners.
class Me {
  const Me({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.learners,
  });

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String,
    role: UserRole.parse(json['role'] as String),
    learners: ((json['students'] as List?) ?? const [])
        .map((s) => Learner.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final List<Learner> learners;

  bool get isParent => role == UserRole.parent;
  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;
}

class CurriculumTopic {
  const CurriculumTopic({required this.name, required this.lessons});

  factory CurriculumTopic.fromJson(Map<String, dynamic> json) =>
      CurriculumTopic(
        name: json['name'] as String,
        lessons: json['lessons'] as int,
      );

  final String name;
  final int lessons;
}

class CurriculumStrand {
  const CurriculumStrand({required this.name, required this.topics});

  factory CurriculumStrand.fromJson(Map<String, dynamic> json) =>
      CurriculumStrand(
        name: json['name'] as String,
        topics: (json['topics'] as List)
            .map((t) => CurriculumTopic.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  final String name;
  final List<CurriculumTopic> topics;
}
