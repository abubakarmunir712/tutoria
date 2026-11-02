import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/conversations.dart';
import '../../core/design/design.dart';
import '../home/student_home_screen.dart' show sinceLabel;

/// A learner's saved tutor chats, newest first. Tapping one pops it so the caller can reopen it.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key, required this.learnerId, this.subject});

  final String learnerId;

  /// Only this subject's chats; null lists them all.
  final String? subject;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<ConversationSummary>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await context.read<ApiClient>().conversations(
        widget.learnerId,
        subject: widget.subject,
      );
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load past conversations. Check your '
              'connection.',
        );
      }
    }
  }

  Future<void> _delete(ConversationSummary c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this conversation?'),
        content: Text(c.title, maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiClient>().deleteConversation(
        widget.learnerId,
        c.id,
      );
      if (mounted) {
        setState(() => _items = _items!.where((x) => x != c).toList());
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not delete it. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Past conversations')),
      body: SafeArea(
        child: items == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TText.body),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
              )
            : items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(TSpace.page),
                  child: Text(
                    'Nothing here yet. Ask the tutor something and it will '
                    'be saved so you can carry on later.',
                    textAlign: TextAlign.center,
                    style: TText.body,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  TSpace.page,
                  TSpace.sm,
                  TSpace.page,
                  TSpace.xl,
                ),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TSpace.sm),
                      child: Text(
                        _error!,
                        style: TText.small.copyWith(color: TColors.danger),
                      ),
                    ),
                  for (final c in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TSpace.md),
                      child: _ConversationTile(
                        conversation: c,
                        showSubject: widget.subject == null,
                        onTap: () => Navigator.pop(context, c),
                        onDelete: () => _delete(c),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.showSubject,
    required this.onTap,
    required this.onDelete,
  });

  final ConversationSummary conversation;
  final bool showSubject;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final style = SubjectStyle.of(c.subject);
    final turns = (c.messages / 2).ceil();
    final detail = [
      if (showSubject) c.subject,
      '$turns ${turns == 1 ? 'question' : 'questions'}',
      sinceLabel(c.lastMessageAt, DateTime.now()),
    ].join(' · ');
    return TCard(
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(icon: style.icon, color: style.accent, size: 40),
          const SizedBox(width: TSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TText.bodyBold,
                ),
                const SizedBox(height: 2),
                Text(detail, style: TText.small),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete conversation',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
