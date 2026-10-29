import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/parent_provider.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

/// The app as a parent sees it: their children, notifications about them, settings.
class ParentShell extends StatelessWidget {
  const ParentShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavProvider>();
    final unread = context.select<DataProvider, int>((d) => d.unread);

    return Scaffold(
      body: IndexedStack(
        index: nav.index,
        children: const [ChildrenScreen(), NotificationsScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.index,
        onDestinationSelected: nav.go,
        height: 68,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.family_restroom_outlined),
            selectedIcon: const Icon(Icons.family_restroom_rounded),
            label: context.tr('nav_children'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: Brand.danger,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: Brand.danger,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: context.tr('nav_notifications'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: context.tr('nav_settings'),
          ),
        ],
      ),
    );
  }
}

class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ParentProvider>();
    final name = context.select<AuthProvider, String>((a) => a.user?.name ?? '');

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('children_title'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: RefreshIndicator(
        color: Brand.primary,
        onRefresh: p.refreshChildren,
        child: p.children.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: p.loading
                      ? const Center(child: CircularProgressIndicator(color: Brand.primary))
                      : p.failed
                          ? EmptyStateRetry(
                              message: context.tr('children_load_failed'),
                              retryLabel: context.tr('retry'),
                              onRetry: p.refreshChildren,
                            )
                          : EmptyState(
                              icon: Icons.family_restroom_rounded,
                              title: context.tr('children_empty'),
                              note: context.tr('children_empty_note'),
                            ),
                ),
              ])
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: p.children.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                      child: Text(context.tr('hello_parent', {'name': name}),
                          style: const TextStyle(fontSize: 15, color: Brand.muted, fontWeight: FontWeight.w600)),
                    );
                  }
                  final c = p.children[i - 1];
                  return _ChildCard(child: c);
                },
              ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});
  final ChildSummary child;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().code;
    final ratio = child.total == 0 ? 0.0 : child.present / child.total;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChildDetailScreen(child: child))),
      child: SoftCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Brand.primary,
              child: Text(child.name.isNotEmpty ? child.name.characters.first.toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(child.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.text)),
                if (child.grade.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(child.grade, style: const TextStyle(fontSize: 13, color: Brand.muted)),
                  ),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Brand.muted),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _Stat(value: '${child.present}', label: context.tr('present'), color: Brand.primary)),
            Expanded(child: _Stat(value: '${child.absent}', label: context.tr('absent'), color: Brand.danger)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: Brand.border, color: Brand.primary),
          ),
          const SizedBox(height: 6),
          Text(
            child.lastAttended == null
                ? context.tr('never_attended')
                : context.tr('last_attended', {'date': formatDay(child.lastAttended, lang)}),
            style: const TextStyle(fontSize: 12.5, color: Brand.muted),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Brand.muted, fontWeight: FontWeight.w600)),
      ]);
}

class ChildDetailScreen extends StatefulWidget {
  const ChildDetailScreen({super.key, required this.child});
  final ChildSummary child;

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  bool _failed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ok = await context.read<ParentProvider>().refreshChild(widget.child.id);
    if (!mounted) return;
    setState(() {
      _failed = !ok;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ParentProvider>();
    final lang = context.watch<LocaleProvider>().code;
    final records = p.attendanceOf(widget.child.id);

    // Attendance only: the app is an attendance companion and shows no course content.
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.child.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Column(children: [
          if (_failed && (records != null)) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: OfflineBanner(text: context.tr('saved_data'))),
          Expanded(
            child: records == null
                ? (_loading
                    ? const Center(child: CircularProgressIndicator(color: Brand.primary))
                    : EmptyStateRetry(message: context.tr('children_load_failed'), retryLabel: context.tr('retry'), onRetry: _load))
                : RefreshIndicator(color: Brand.primary, onRefresh: _load, child: _AttendanceList(records: records, lang: lang)),
          ),
        ]),
    );
  }
}

class _AttendanceList extends StatelessWidget {
  const _AttendanceList({required this.records, required this.lang});
  final List<AttendanceRecord> records;
  final String lang;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
        SizedBox(
          height: 360,
          child: EmptyState(icon: Icons.event_busy_rounded, title: context.tr('child_attendance_empty'), note: ''),
        ),
      ]);
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = records[i];
        final ok = r.isPresent;
        final color = ok ? Brand.primary : Brand.danger;
        final sub = [if (r.center != null && r.center!.isNotEmpty) r.center!, formatDay(r.date, lang)].where((s) => s.isNotEmpty).join(' - ');
        return SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
              child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.course, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Brand.text)),
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(fontSize: 12.5, color: Brand.muted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(context.tr(ok ? 'present' : 'absent'), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      },
    );
  }
}

/// Parents whose first password was set by the school must choose their own before anything else.
class ParentPasswordScreen extends StatefulWidget {
  const ParentPasswordScreen({super.key});

  @override
  State<ParentPasswordScreen> createState() => _ParentPasswordScreenState();
}

class _ParentPasswordScreenState extends State<ParentPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final fallback = context.trRead('password_change_failed');
    try {
      await auth.changeParentPassword(_current.text, _new.text, _confirm.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.fieldErrors.values.isNotEmpty ? e.fieldErrors.values.first : (e.isOffline ? context.trRead('login_needs_internet') : fallback);
        _busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = fallback;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('set_password_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => context.read<AuthProvider>().logout(),
            child: Text(context.tr('logout')),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(context.tr('set_password_note'), style: const TextStyle(fontSize: 14.5, color: Brand.muted, height: 1.4)),
          const SizedBox(height: 18),
          Form(
            key: _form,
            child: Column(children: [
              _pwField(_current, context.tr('current_password'), validator: (v) => (v == null || v.isEmpty) ? context.trRead('field_required') : null),
              const SizedBox(height: 14),
              _pwField(_new, context.tr('new_password'),
                  validator: (v) => (v == null || v.length < 8) ? context.trRead('password_min') : null),
              const SizedBox(height: 14),
              _pwField(_confirm, context.tr('confirm_password'),
                  validator: (v) => v != _new.text ? context.trRead('password_mismatch') : null),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 22),
          GradientButton(label: context.tr('save'), loading: _busy, onPressed: _submit),
        ]),
      ),
    );
  }

  Widget _pwField(TextEditingController c, String label, {required String? Function(String?) validator}) => TextFormField(
        controller: c,
        obscureText: true,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.lock_outline_rounded)),
        validator: validator,
      );
}
