import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/data_provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lang = context.watch<LocaleProvider>().code;
    final items = data.notifications;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('notifications_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (data.unread > 0)
            IconButton(
              tooltip: context.tr('mark_all_read'),
              icon: const Icon(Icons.done_all_rounded, color: Brand.primaryDark),
              onPressed: data.markAllRead,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: Brand.primary,
        onRefresh: data.refreshNotifications,
        child: items.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: data.notificationsLoading
                      ? const Center(child: CircularProgressIndicator(color: Brand.primary))
                      : EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: context.tr('notifications_empty'),
                          note: context.tr('notifications_empty_note'),
                        ),
                ),
              ])
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _NotificationTile(item: items[i], lang: lang),
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.lang});
  final AppNotification item;
  final String lang;

  IconData get _icon {
    switch (item.type) {
      case 'attendance_confirmed':
        return Icons.how_to_reg_rounded;
      case 'teacher_message':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    return Card(
      color: unread ? const Color(0xFFF0FDF4) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.read<DataProvider>().markRead(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (unread ? Brand.primary : Brand.muted).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_icon, color: unread ? Brand.primary : Brand.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(item.title,
                        style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600, fontSize: 15, color: Brand.text)),
                  ),
                  if (unread)
                    Container(width: 9, height: 9, decoration: const BoxDecoration(color: Brand.primary, shape: BoxShape.circle)),
                ]),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(item.body, style: const TextStyle(fontSize: 13.5, color: Brand.muted, height: 1.4)),
                ],
                const SizedBox(height: 6),
                Text(formatDateTime(item.created, lang), style: const TextStyle(fontSize: 11.5, color: Brand.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
