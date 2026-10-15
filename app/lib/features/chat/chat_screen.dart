import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/activity.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/design/design.dart';
import '../../core/grade_labels.dart';
import '../../core/voice.dart';

class _ChatMessage {
  _ChatMessage.user(this.text)
    : isUser = true,
      citations = const [],
      imagePath = null;
  _ChatMessage.image(this.imagePath)
    : isUser = true,
      text = null,
      citations = const [];
  _ChatMessage.ai(this.text, this.citations) : isUser = false, imagePath = null;

  final bool isUser;
  final String? text;
  final String? imagePath;
  final List<ChatCitation> citations;
}

/// The tutor chat for one subject: ask in words or with a photo of the homework.
///
/// [initialQuestion] is sent as soon as the screen opens (a topic tapped in the topic list);
/// [startWithCamera] opens the camera straight away ("Take a Picture" on the home screen).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.grade,
    required this.subject,
    this.initialQuestion,
    this.startWithCamera = false,
    this.startWithVoice = false,
    this.learnerId,
    this.topic,
  });

  final String? grade;
  final String subject;
  final String? initialQuestion;
  final bool startWithCamera;

  /// Starts listening straight away ("Voice Tutor" on the home screen).
  final bool startWithVoice;

  /// Whose chat this is and, if it was opened from the topic list, which topic; used to
  /// remember where the learner left off.
  final String? learnerId;
  final String? topic;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _sending = false;
  bool _recording = false;
  bool _transcribing = false;

  /// The tutor message being read aloud (or fetched to be), if any.
  int? _speakingIndex;
  bool _loadingSpeech = false;

  @override
  void initState() {
    super.initState();
    _voice = context.read<VoiceService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialQuestion != null) {
        _sendText(widget.initialQuestion);
      } else if (widget.startWithCamera) {
        _sendImage(ImageSource.camera);
      } else if (widget.startWithVoice) {
        _toggleMic();
      }
    });
  }

  @override
  void dispose() {
    // Leaving the chat must not leave the microphone open or the tutor talking.
    if (_recording) unawaited(_voice.stopRecording());
    if (_speakingIndex != null) unawaited(_voice.stopPlayback());
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ApiClient get _api => context.read<ApiClient>();

  void _recordActivity() {
    final id = widget.learnerId;
    if (id == null) return;
    unawaited(
      context.read<ActivityTracker>().record(
        id,
        subject: widget.subject,
        topic: widget.topic,
      ),
    );
  }

  /// Kept from initState: dispose() can't look anything up through the context.
  late final VoiceService _voice;

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
          final content =
              m.text ?? (m.imagePath != null ? '[Sent a homework photo]' : '');
          return {'role': m.isUser ? 'user' : 'assistant', 'content': content};
        })
        .where((m) => m['content']!.isNotEmpty)
        .toList();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addAiMessage(String text, [List<ChatCitation> citations = const []]) {
    if (!mounted) return;
    setState(() => _messages.add(_ChatMessage.ai(text, citations)));
    _scrollToEnd();
  }

  /// [spoken] marks a question the child said aloud: the tutor then answers aloud too.
  Future<void> _sendText([String? preset, bool spoken = false]) async {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _sending) return;
    if (preset == null) _controller.clear();
    _recordActivity();
    final history = _buildHistory();
    setState(() {
      _messages.add(_ChatMessage.user(question));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final response = await _api.askQuestion(
        question: question,
        grade: widget.grade,
        subject: widget.subject,
        history: history,
      );
      _addAiMessage(response.answer, response.citations);
      if (spoken) {
        unawaited(_speak(_messages.length - 1));
      }
    } on ApiException catch (e) {
      _addAiMessage('Error: ${e.message}');
    } catch (_) {
      _addAiMessage(
        "I couldn't reach the tutor. Check your internet connection and try again.",
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Tap once to start talking, again to stop. The words are shown as the child's message and
  /// answered like any typed question.
  Future<void> _toggleMic() async {
    if (_sending || _transcribing || _loadingSpeech) return;
    if (!_recording) {
      await _stopSpeaking();
      try {
        final started = await _voice.startRecording();
        if (!mounted) return;
        if (!started) {
          _addAiMessage(
            "I can't hear you yet. Allow microphone access for Tutoria in your phone's "
            'Settings, or type your question instead.',
          );
          return;
        }
        setState(() => _recording = true);
      } catch (_) {
        _addAiMessage(
          "I couldn't start the microphone. Please type your question instead.",
        );
      }
      return;
    }

    setState(() {
      _recording = false;
      _transcribing = true;
    });
    String text = '';
    try {
      final file = await _voice.stopRecording();
      if (file != null) text = await _api.transcribeAudio(file);
    } on ApiException catch (e) {
      _addAiMessage('Error: ${e.message}');
    } catch (_) {
      _addAiMessage(
        "I couldn't send your voice. Check your internet connection and try again.",
      );
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
    if (!mounted) return;
    if (text.isEmpty) {
      if (_messages.isEmpty || _messages.last.isUser) {
        _addAiMessage(
          "I couldn't hear a question. Tap the microphone and try again, a little closer to your phone.",
        );
      }
      return;
    }
    await _sendText(text, true);
  }

  Future<void> _stopSpeaking() async {
    if (_speakingIndex == null && !_loadingSpeech) return;
    setState(() {
      _speakingIndex = null;
      _loadingSpeech = false;
    });
    await _voice.stopPlayback();
  }

  /// Reads one tutor message aloud; tapping it again while it plays stops it.
  Future<void> _speak(int index) async {
    if (_speakingIndex == index) {
      await _stopSpeaking();
      return;
    }
    await _stopSpeaking();
    final text = _messages[index].text;
    if (text == null || !mounted) return;
    setState(() {
      _speakingIndex = index;
      _loadingSpeech = true;
    });
    try {
      final audio = await _api.speak(text);
      if (!mounted || _speakingIndex != index) return;
      setState(() => _loadingSpeech = false);
      await _voice.play(audio);
    } catch (_) {
      if (mounted && _speakingIndex == index) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("I couldn't read that aloud. Try again."),
          ),
        );
      }
    } finally {
      if (mounted && _speakingIndex == index) {
        setState(() {
          _speakingIndex = null;
          _loadingSpeech = false;
        });
      }
    }
  }

  Future<void> _choosePhotoSource() async {
    if (_sending) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const IconBadge(
                icon: Icons.photo_camera_rounded,
                color: TColors.socialAccent,
                size: 40,
              ),
              title: Text(
                'Take a photo of your homework',
                style: TText.bodyBold,
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const IconBadge(
                icon: Icons.photo_library_rounded,
                color: TColors.englishAccent,
                size: 40,
              ),
              title: Text('Choose from your photos', style: TText.bodyBold),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: TSpace.sm),
          ],
        ),
      ),
    );
    if (source != null) await _sendImage(source);
  }

  Future<void> _sendImage(ImageSource source) async {
    if (_sending) return;
    XFile? picked;
    try {
      // Phone cameras take 8-12 MB photos; the text is just as readable at 1600 px, and the
      // upload is several times faster on a mobile connection.
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
    } on PlatformException {
      _addAiMessage(
        source == ImageSource.camera
            ? "I can't use the camera yet. Allow camera access for Tutoria in your phone's "
                  'Settings, or choose a photo from your gallery instead.'
            : "I can't open your photos yet. Allow photo access for Tutoria in your phone's Settings.",
      );
      return;
    }
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    _recordActivity();
    final history = _buildHistory();
    setState(() {
      _messages.add(_ChatMessage.image(file.path));
      _sending = true;
    });
    _scrollToEnd();
    try {
      final response = await _api.askWithImage(
        image: file,
        grade: widget.grade,
        subject: widget.subject,
        history: history,
      );
      _addAiMessage(response.answer, response.citations);
    } on ApiException catch (e) {
      _addAiMessage('Error: ${e.message}');
    } catch (_) {
      _addAiMessage(
        "I couldn't send that photo. Check your internet connection and try again.",
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(widget.subject);
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: TColors.heroGradient),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            IconBadge(
              icon: style.icon,
              color: Colors.white.withValues(alpha: 0.22),
              size: 38,
            ),
            const SizedBox(width: TSpace.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.subject} Tutor',
                  style: TText.subheading.copyWith(color: Colors.white),
                ),
                if (widget.grade != null)
                  Text(
                    gradeLabel(widget.grade),
                    style: TText.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyChat(
                    subject: widget.subject,
                    onPrompt: _sendText,
                    onPhoto: _choosePhotoSource,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      TSpace.lg,
                      TSpace.lg,
                      TSpace.lg,
                      TSpace.sm,
                    ),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, i) => i == _messages.length
                        ? const _TypingBubble()
                        : _MessageBubble(
                            message: _messages[i],
                            speaking: _speakingIndex == i,
                            loadingSpeech:
                                _speakingIndex == i && _loadingSpeech,
                            onListen: () => _speak(i),
                          ),
                  ),
          ),
          _Composer(
            controller: _controller,
            sending: _sending,
            recording: _recording,
            transcribing: _transcribing,
            onSend: _sendText,
            onPhoto: _choosePhotoSource,
            onMic: _toggleMic,
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({
    required this.subject,
    required this.onPrompt,
    required this.onPhoto,
  });

  final String subject;
  final ValueChanged<String> onPrompt;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final prompts = [
      'Help me with my homework',
      'Explain something I don’t understand',
      'Show me an example',
    ];
    return ListView(
      padding: const EdgeInsets.all(TSpace.page),
      children: [
        const SizedBox(height: TSpace.xl),
        const Center(child: Mascot(size: 120)),
        const SizedBox(height: TSpace.lg),
        Text(
          'Hi! I’m your $subject tutor',
          textAlign: TextAlign.center,
          style: TText.heading,
        ),
        const SizedBox(height: 6),
        Text(
          'Ask me anything, or send a photo of your homework.',
          textAlign: TextAlign.center,
          style: TText.body.copyWith(color: TColors.muted),
        ),
        const SizedBox(height: TSpace.xl),
        for (final p in prompts) ...[
          TButton(
            label: p,
            style: TButtonStyle.soft,
            onPressed: () => onPrompt(p),
          ),
          const SizedBox(height: TSpace.md),
        ],
        TButton(
          label: 'Send a photo of my homework',
          icon: Icons.photo_camera_rounded,
          style: TButtonStyle.outline,
          onPressed: onPhoto,
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.recording,
    required this.transcribing,
    required this.onSend,
    required this.onPhoto,
    required this.onMic,
  });

  final TextEditingController controller;
  final bool sending;
  final bool recording;
  final bool transcribing;
  final VoidCallback onSend;
  final VoidCallback onPhoto;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TColors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0245B0),
            blurRadius: 16,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TSpace.md,
            TSpace.md,
            TSpace.md,
            TSpace.md,
          ),
          child: Row(
            children: [
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: TColors.blue100,
                  foregroundColor: TColors.blue600,
                ),
                tooltip: 'Add a homework photo',
                onPressed: sending || recording || transcribing
                    ? null
                    : onPhoto,
                icon: const Icon(Icons.photo_camera_rounded),
              ),
              const SizedBox(width: TSpace.sm),
              Expanded(
                child: recording || transcribing
                    ? _VoiceStatus(recording: recording)
                    : TextField(
                        controller: controller,
                        enabled: !sending,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        style: TText.body.copyWith(
                          color: TColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your question…',
                          filled: true,
                          fillColor: TColors.blue50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(TRadius.pill),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(TRadius.pill),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(TRadius.pill),
                            borderSide: const BorderSide(
                              color: TColors.blue600,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: TSpace.sm),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: recording ? TColors.danger : TColors.blue100,
                  foregroundColor: recording ? Colors.white : TColors.blue600,
                ),
                tooltip: recording ? 'Stop and send' : 'Ask with your voice',
                onPressed: sending || transcribing ? null : onMic,
                icon: Icon(recording ? Icons.stop_rounded : Icons.mic_rounded),
              ),
              const SizedBox(width: TSpace.sm),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: TColors.blue600,
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Send',
                onPressed: sending || recording || transcribing ? null : onSend,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the text field while the child is speaking or the words are being read.
class _VoiceStatus extends StatelessWidget {
  const _VoiceStatus({required this.recording});

  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: TColors.blue50,
        borderRadius: BorderRadius.circular(TRadius.pill),
      ),
      child: Row(
        children: [
          if (recording)
            const Icon(Icons.graphic_eq_rounded, color: TColors.danger)
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          const SizedBox(width: TSpace.sm),
          Expanded(
            child: Text(
              recording
                  ? 'Listening… tap the red button when done'
                  : 'Got it, writing it down…',
              style: TText.body.copyWith(
                color: TColors.ink,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three bouncing dots while the tutor is thinking.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const _TutorAvatar(),
          const SizedBox(width: TSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              color: TColors.blue100,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TColors.blue600.withValues(
                          alpha:
                              0.35 +
                              0.65 *
                                  ((((_c.value * 3) - i) % 3) < 1
                                      ? 1 - (((_c.value * 3) - i) % 3)
                                      : 0),
                        ),
                      ),
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

class _TutorAvatar extends StatelessWidget {
  const _TutorAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: TColors.blue200),
      ),
      child: const Padding(padding: EdgeInsets.all(2), child: Mascot(size: 30)),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.speaking = false,
    this.loadingSpeech = false,
    this.onListen,
  });

  final _ChatMessage message;
  final bool speaking;
  final bool loadingSpeech;
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    final user = message.isUser;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: message.imagePath != null
          ? const EdgeInsets.all(6)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: user ? TColors.blue600 : TColors.blue100,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(user ? 18 : 4),
          bottomRight: Radius.circular(user ? 4 : 18),
        ),
      ),
      child: message.imagePath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(File(message.imagePath!), width: 200),
            )
          : user
          ? Text(
              message.text ?? '',
              style: TText.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            )
          : MarkdownBody(
              data: message.text ?? '',
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TText.body.copyWith(color: TColors.ink),
                strong: TText.bodyBold.copyWith(color: TColors.ink),
                em: TText.body.copyWith(
                  color: TColors.ink,
                  fontStyle: FontStyle.italic,
                ),
                listBullet: TText.body.copyWith(color: TColors.ink),
                blockquote: TText.small.copyWith(color: TColors.body),
                blockquotePadding: const EdgeInsets.all(10),
                blockquoteDecoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: TColors.blue500, width: 4),
                  ),
                ),
                pPadding: const EdgeInsets.only(bottom: 2),
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          user
              ? bubble
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const _TutorAvatar(),
                    const SizedBox(width: TSpace.sm),
                    Flexible(child: bubble),
                  ],
                ),
          if (!user && onListen != null && (message.text ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 38),
              child: TextButton.icon(
                onPressed: onListen,
                style: TextButton.styleFrom(
                  foregroundColor: TColors.blue600,
                  visualDensity: VisualDensity.compact,
                ),
                icon: loadingSpeech
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        speaking
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        size: 20,
                      ),
                label: Text(
                  loadingSpeech
                      ? 'Getting ready…'
                      : (speaking ? 'Stop' : 'Listen'),
                  style: TText.caption.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (message.citations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 44),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final c in message.citations.take(3))
                    Pill(
                      text: c.indicatorCode,
                      icon: Icons.verified_rounded,
                      background: Colors.white,
                      foreground: TColors.blue600,
                    ),
                ],
              ),
            ),
          if (_citationImages(message.citations).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 44),
              child: SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: _citationImages(message.citations).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
