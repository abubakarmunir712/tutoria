import 'api_client.dart';

/// One saved tutor chat, as listed in the history.
class ConversationSummary {
  ConversationSummary({
    required this.id,
    required this.title,
    required this.subject,
    required this.messages,
    required this.lastMessageAt,
    this.grade,
    this.topic,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        subject: json['subject'] as String,
        grade: json['grade'] as String?,
        topic: json['topic'] as String?,
        messages: json['messages'] as int? ?? 0,
        lastMessageAt:
            DateTime.tryParse(json['lastMessageAt'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  final String id;
  final String title;
  final String subject;
  final String? grade;
  final String? topic;
  final int messages;
  final DateTime lastMessageAt;
}

/// One message of a saved chat.
class SavedMessage {
  SavedMessage({
    required this.isUser,
    required this.content,
    this.hasImage = false,
    this.citations = const [],
  });

  factory SavedMessage.fromJson(Map<String, dynamic> json) => SavedMessage(
    isUser: json['role'] == 'user',
    content: json['content'] as String? ?? '',
    hasImage: json['hasImage'] as bool? ?? false,
    citations: ((json['citations'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatCitation.fromJson)
        .toList(),
  );

  final bool isUser;
  final String content;

  /// A homework photo was sent here. The photo itself is not kept.
  final bool hasImage;
  final List<ChatCitation> citations;
}

/// A saved chat with all its messages.
class SavedConversation {
  SavedConversation({
    required this.id,
    required this.subject,
    required this.messages,
    this.grade,
    this.topic,
  });

  factory SavedConversation.fromJson(Map<String, dynamic> json) =>
      SavedConversation(
        id: json['id'] as String,
        subject: json['subject'] as String,
        grade: json['grade'] as String?,
        topic: json['topic'] as String?,
        messages: (json['messages'] as List)
            .map((m) => SavedMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String subject;
  final String? grade;
  final String? topic;
  final List<SavedMessage> messages;
}
