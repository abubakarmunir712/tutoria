import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/grade_labels.dart';
import '../../core/theme.dart';
import '../auth/auth_state.dart';
import '../chat/chat_screen.dart';

const _grades = ['B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'SHS1', 'SHS2', 'SHS3']; // raw codes — see grade_labels.dart for display names

const _subjectIcons = {
  'Mathematics': Icons.calculate_outlined,
  'English Language': Icons.menu_book_outlined,
  'Science': Icons.science_outlined,
  'Our World and Our People': Icons.public_outlined,
  'Social Studies': Icons.groups_outlined,
  'Computing': Icons.computer_outlined,
};

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _profile;
  List<dynamic> _subjects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await _api.getProfile();
      final subjects = await _api.listSubjects();
      setState(() {
        _profile = profile;
        _subjects = subjects;
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/icon_mark.png', height: 28, width: 28),
            const SizedBox(width: 10),
            const Text('Tutoria'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthState>().logout();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text('Continue where you left off', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.auto_stories_outlined, color: TutoriaColors.blue),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('No lessons started yet — pick a subject below to begin.'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Your grade', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _profile?['grade'] as String?,
                        items: _grades
                            .map((g) => DropdownMenuItem(value: g, child: Text(gradeLabel(g))))
                            .toList(),
                        onChanged: (grade) async {
                          if (grade == null) return;
                          final updated = await _api.updateGrade(grade);
                          setState(() => _profile = updated);
                        },
                        decoration: const InputDecoration(labelText: 'Select grade'),
                      ),
                      const SizedBox(height: 24),
                      Text('Subjects', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ..._subjects.map(
                        (s) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: TutoriaColors.gold.withValues(alpha: 0.2),
                              foregroundColor: TutoriaColors.orange,
                              child: Icon(_subjectIcons[s['name']] ?? Icons.school_outlined),
                            ),
                            title: Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text((s['phase'] as String).replaceAll('_', ' ')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  grade: _profile?['grade'] as String?,
                                  subject: s['name'] as String,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
