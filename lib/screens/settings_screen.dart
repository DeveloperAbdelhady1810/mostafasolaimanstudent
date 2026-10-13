import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/push_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(ctx.trRead('logout_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.trRead('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.trRead('logout'), style: const TextStyle(color: Brand.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final push = context.watch<PushService>();
    final lp = context.watch<LocaleProvider>();
    final user = auth.user;

    final pushSubtitle = !push.available
        ? context.tr('push_unavailable')
        : push.permitted
            ? context.tr('push_on')
            : context.tr('push_off');

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings_title'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // Profile
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Brand.primary,
                child: Text(
                  (user?.name.isNotEmpty ?? false) ? user!.name.characters.first.toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.name ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.text)),
                  if (auth.studentNumber != null) ...[
                    const SizedBox(height: 3),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text('#${auth.studentNumber}', style: const TextStyle(fontSize: 14, color: Brand.primaryDark, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          _SectionLabel(context.tr('account')),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              if ((user?.email ?? '').isNotEmpty)
                _InfoTile(icon: Icons.mail_outline_rounded, label: context.tr('email'), value: user!.email!),
              if ((user?.email ?? '').isNotEmpty && (user?.phone ?? '').isNotEmpty) const Divider(),
              if ((user?.phone ?? '').isNotEmpty)
                _InfoTile(icon: Icons.phone_outlined, label: context.tr('phone'), value: user!.phone!),
            ]),
          ),
          const SizedBox(height: 14),

          _SectionLabel(context.tr('language')),
          SoftCard(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Brand.primary,
                  selectedForegroundColor: Colors.white,
                  foregroundColor: Brand.text,
                ),
                segments: [
                  ButtonSegment(value: 'en', label: Text(context.tr('english'))),
                  ButtonSegment(value: 'ar', label: Text(context.tr('arabic'))),
                ],
                selected: {lp.code},
                onSelectionChanged: (s) => lp.setLanguage(s.first),
              ),
            ),
          ),
          const SizedBox(height: 14),

          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined, color: Brand.primary),
                title: Text(context.tr('push_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(pushSubtitle),
                trailing: push.available && !push.permitted ? const Icon(Icons.chevron_right_rounded) : null,
                onTap: push.available && !push.permitted ? () => context.read<PushService>().enable() : null,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.language_rounded, color: Brand.primary),
                title: Text(context.tr('open_website'), style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(Uri.parse(siteUrl), mode: LaunchMode.externalApplication),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Brand.primary),
                title: Text(context.tr('version'), style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(appVersionLabel, style: const TextStyle(color: Brand.muted)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.tr('logout')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Brand.danger,
              side: const BorderSide(color: Brand.danger),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Brand.muted)),
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Brand.primary),
        title: Text(label, style: const TextStyle(fontSize: 12.5, color: Brand.muted, fontWeight: FontWeight.w600)),
        subtitle: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: const TextStyle(fontSize: 15, color: Brand.text, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}
