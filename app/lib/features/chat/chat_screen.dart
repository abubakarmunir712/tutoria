import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/grade_labels.dart';

class _ChatMessage {
  _ChatMessage.user(this.text) : isUser = true, citations = const [], imagePath = null;
  _ChatMessage.image(this.imagePath) : isUser = true, text = null, citations = const [];
  _ChatMessage.ai(this.text, this.citations) : isUser = false, imagePath = null;

  final bool isUser;
  final String? text;
  final String? imagePath;
  final List<ChatCitation> citations;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.grade, required this.subject});

  final String? grade;
  final String subject;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];
  bool _sending = false;

  /// Prior turns in this conversation, oldest first — captured before the new
  /// message is appended, and capped so the request body doesn't grow unbounded
  /// over a long session.
  List<Map<String, String>> _buildHistory() {
    const maxTurns = 10;
    final recent = _messages.length > maxTurns
        ? _messages.sublist(_messages.length - maxTurns)
        : _messages;
    return recent
        .map((m) {
          final content = m.text ?? (m.imagePath != null ? '[Sent a homework photo]' : '');
          return {'role': m.isUser ? 'user' : 'assistant', 'content': content};
        })
        .where((m) => m['content']!.isNotEmpty)
        .toList();
  }

  Future<void> _sendText() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _sending) return;
    _controller.clear();
    final history = _buildHistory();
    setState(() {
      _messages.add(_ChatMessage.user(question));
      _sending = true;
    });
    try {
      final response = await _api.askQuestion(
        question: question,
        grade: widget.grade,
        subject: widget.subject,
        history: history,
      );
      setState(() => _messages.add(_ChatMessage.ai(response.answer, response.citations)));
    } on ApiException catch (e) {
      setState(() => _messages.add(_ChatMessage.ai('Error: ${e.message}', const [])));
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_sending) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _messages.add(_ChatMessage.image(file.path));
      _sending = true;
    });
    try {
      final response = await _api.askWithImage(
        image: file,
        grade: widget.grade,
        subject: widget.subject,
      );
      setState(() => _messages.add(_ChatMessage.ai(response.answer, response.citations)));
    } on ApiException catch (e) {
      setState(() => _messages.add(_ChatMessage.ai('Error: ${e.message}', const [])));
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject} Tutor'),
        bottom: widget.grade == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    gradeLabel(widget.grade),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _MessageBubble(message: _messages[i]),
            ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_camera_outlined),
                    onPressed: _sendImage,
                    tooltip: 'Upload homework photo',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ask a question...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor =
        message.isUser ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(12)),
            child: message.imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(message.imagePath!), width: 200),
                  )
                : message.isUser
                    ? Text(message.text ?? '')
                    : MarkdownBody(
                        data: message.text ?? '',
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                          p: theme.textTheme.bodyMedium,
                          strong: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                          listBullet: theme.textTheme.bodyMedium,
                        ),
                      ),
          ),
          if (message.citations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                children: message.citations
                    .map((c) => Chip(
                          label: Text(c.indicatorCode, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ),
          if (_citationImages(message.citations).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _citationImages(message.citations).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      '$apiBaseUrl/${_citationImages(message.citations)[i]}',
                      height: 90,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 90,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _citationImages(List<ChatCitation> citations) =>
      citations.expand((c) => c.images).toSet().toList();
}
