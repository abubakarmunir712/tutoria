import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/design/design.dart';
import '../../core/leaderboard.dart';

/// This week's XP board for the learner's class. Only a first name and initial are shown, and a
/// learner (or their parent) can step off the board.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.learnerId});

  final String learnerId;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Leaderboard? _board;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final b = await context.read<ApiClient>().leaderboard(widget.learnerId);
      if (mounted) setState(() => _board = b);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load the leaderboard. Check your '
              'connection.',
        );
      }
    }
  }

  Future<void> _setVisible(bool visible) async {
    setState(() => _saving = true);
    try {
      await context.read<ApiClient>().setLeaderboardVisible(
        widget.learnerId,
        visible,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save that. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return Scaffold(
      appBar: AppBar(title: const Text('Class leaderboard')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: TColors.pageGradient),
        child: SafeArea(
          child: board == null
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(TSpace.page),
                    children: [
                      Text(
                        'XP earned this week by learners in your class. '
                        'Everyone starts again on Monday.',
                        style: TText.body,
                      ),
                      const SizedBox(height: TSpace.lg),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: TSpace.sm),
                          child: Text(
                            _error!,
                            style: TText.small.copyWith(color: TColors.danger),
                          ),
                        ),
                      if (board.top.isEmpty)
                        TCard(
                          child: Text(
                            'No one has earned XP this week yet. Ask a '
                            'question or take a quiz to get on the board!',
                            style: TText.body,
                          ),
                        )
                      else ...[
                        for (final r in board.top) _RowTile(row: r),
                        if (board.you != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: TSpace.xs,
                            ),
                            child: Center(
                              child: Text('· · ·', style: TText.small),
                            ),
                          ),
                          _RowTile(row: board.you!),
                        ],
                      ],
                      const SizedBox(height: TSpace.xl),
                      TCard(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Show me on the leaderboard',
                            style: TText.bodyBold,
                          ),
                          subtitle: Text(
                            'Others only see a first name and initial.',
                            style: TText.small,
                          ),
                          value: !board.hidden,
                          onChanged: _saving ? null : _setVisible,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final BoardRow row;

  @override
  Widget build(BuildContext context) {
    final medal = switch (row.rank) {
      1 => const Color(0xFFFFC21A),
      2 => const Color(0xFFB8C2CC),
      3 => const Color(0xFFD9915A),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: TSpace.sm),
      child: TCard(
        color: row.isYou ? TColors.blue50 : TColors.white,
        borderColor: row.isYou ? TColors.blue600 : TColors.line,
        shadow: false,
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: medal == null
                  ? Text('${row.rank}', style: TText.subheading)
                  : Icon(Icons.emoji_events_rounded, color: medal),
            ),
            Expanded(
              child: Text(
                row.isYou ? '${row.name} (you)' : row.name,
                style: TText.bodyBold,
              ),
            ),
            Text('${row.xp} XP', style: TText.bodyBold),
          ],
        ),
      ),
    );
  }
}
