import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/broadcast_provider.dart';
import '../providers/code_provider.dart';
import '../providers/data_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/nav_provider.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final user = auth.user;
    final first = (user?.name ?? '').trim().split(' ').first;

    return Scaffold(
      body: RefreshIndicator(
        color: Brand.primary,
        onRefresh: () async {
          await Future.wait([data.syncAll(), auth.refreshSecret()]);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: Brand.gradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 74),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          context.tr('hello_name', {'name': first}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(context.tr('home_subtitle'), style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 14)),
                      ]),
                    ),
                    _StatusChip(offline: data.offline),
                  ]),
                ),
              ),
            ),

            // Cards overlapping the header
            Transform.translate(
              offset: const Offset(0, -52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(children: [
                  if (data.offline) ...[
                    OfflineBanner(text: context.tr('offline_banner')),
                    const SizedBox(height: 12),
                  ],
                  if (auth.studentNumber == null)
                    EmptyCard(title: context.tr('no_student_number'), note: context.tr('no_student_number_note'))
                  else ...[
                    _IdCard(number: auth.studentNumber!),
                    const SizedBox(height: 14),
                    const _CodeCard(),
                    if (auth.hasSecureCode) ...[
                      const SizedBox(height: 14),
                      const _BroadcastCard(),
                    ],
                  ],
                  const SizedBox(height: 14),
                  const _TilesRow(),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: Brand.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.offline_bolt_rounded, color: Brand.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(context.tr('works_offline'), style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.text)),
                          const SizedBox(height: 2),
                          Text(context.tr('works_offline_note'), style: const TextStyle(fontSize: 12.5, color: Brand.muted, height: 1.4)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.title, required this.note});
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.all(22),
        child: EmptyState(icon: Icons.badge_outlined, title: title, note: note),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.offline});
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: offline ? const Color(0xFFFBBF24) : const Color(0xFF86EFAC), shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(context.tr(offline ? 'status_offline' : 'status_online'),
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _IdCard extends StatelessWidget {
  const _IdCard({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('student_id'), style: const TextStyle(fontSize: 13, color: Brand.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text('$number',
                  key: const Key('student_id_text'),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Brand.primaryDark, letterSpacing: 2)),
            ),
          ]),
        ),
        IconButton.filledTonal(
          tooltip: context.tr('copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: '$number'));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(context.trRead('id_copied')), behavior: SnackBarBehavior.floating));
            }
          },
          icon: const Icon(Icons.copy_rounded),
        ),
      ]),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard();

  @override
  Widget build(BuildContext context) {
    final code = context.watch<CodeProvider>();
    final payload = code.payload;
    if (payload == null) return const SizedBox.shrink();

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (code.isRotating ? Brand.primary : Brand.muted).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(code.isRotating ? Icons.shield_rounded : Icons.qr_code_2_rounded,
                  size: 15, color: code.isRotating ? Brand.primaryDark : Brand.muted),
              const SizedBox(width: 5),
              Text(context.tr(code.isRotating ? 'code_secure' : 'code_basic'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: code.isRotating ? Brand.primaryDark : Brand.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          if (code.isRotating)
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Flexible(
                  child: Text(context.tr('refreshes_in', {'s': code.secondsLeft}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Brand.muted, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    value: code.progress,
                    strokeWidth: 3.5,
                    backgroundColor: Brand.border,
                    color: code.secondsLeft <= 5 ? Brand.warning : Brand.primary,
                  ),
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
        Container(
          key: const Key('qr_code'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Brand.border),
          ),
          child: QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: 240,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF064E3B)),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF064E3B)),
          ),
        ),
        const SizedBox(height: 12),
        Text(context.tr('show_code'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: Brand.muted, fontWeight: FontWeight.w600)),
        if (!code.isRotating) ...[
          const SizedBox(height: 6),
          Text(context.tr('code_basic_note'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Brand.muted, height: 1.4)),
        ],
      ]),
    );
  }
}

/// Bluetooth check-in: broadcasts the rotating code for 60 s so the assistant's radar can see the whole class.
class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard();

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BroadcastProvider>();
    final active = b.status == BroadcastStatus.active;
    final starting = b.status == BroadcastStatus.starting;

    String message;
    switch (b.status) {
      case BroadcastStatus.active:
        message = context.tr('ble_active');
        break;
      case BroadcastStatus.starting:
        message = context.tr('ble_starting');
        break;
      case BroadcastStatus.needsPermission:
        message = context.tr('ble_need_permission');
        break;
      case BroadcastStatus.bluetoothOff:
        message = context.tr('ble_off');
        break;
      case BroadcastStatus.unsupported:
        message = context.tr('ble_unsupported');
        break;
      case BroadcastStatus.error:
        message = context.tr('ble_error');
        break;
      case BroadcastStatus.idle:
        message = context.tr('ble_idle');
        break;
    }

    final problem = b.status == BroadcastStatus.needsPermission ||
        b.status == BroadcastStatus.bluetoothOff ||
        b.status == BroadcastStatus.error ||
        b.status == BroadcastStatus.unsupported;
    final accent = problem ? Brand.warning : Brand.accent;
    final canTap = b.status != BroadcastStatus.unsupported && !starting;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
            child: Icon(active ? Icons.bluetooth_audio_rounded : Icons.bluetooth_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('ble_title'), style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.text, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(message, style: const TextStyle(fontSize: 12.5, color: Brand.muted, height: 1.4)),
            ]),
          ),
        ]),
        if (active) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              key: const Key('ble_progress'),
              value: b.progress,
              minHeight: 6,
              backgroundColor: Brand.border,
              color: Brand.accent,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(context.tr('ble_seconds_left', {'s': b.secondsLeft}),
                style: const TextStyle(fontSize: 12, color: Brand.muted, fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: active
              ? OutlinedButton.icon(
                  key: const Key('ble_stop'),
                  onPressed: b.stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(context.tr('ble_stop')),
                )
              : FilledButton.icon(
                  key: const Key('ble_start'),
                  style: FilledButton.styleFrom(backgroundColor: Brand.primary, minimumSize: const Size.fromHeight(46)),
                  onPressed: !canTap ? null : () => b.start(userInitiated: true),
                  icon: starting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: Text(context.tr(b.hasBroadcastBefore ? 'ble_again' : 'ble_start')),
                ),
        ),
        if (b.status == BroadcastStatus.needsPermission)
          TextButton(
            key: const Key('ble_settings'),
            onPressed: b.openSettings,
            child: Text(context.tr('ble_open_settings')),
          ),
      ]),
    );
  }
}

class _TilesRow extends StatelessWidget {
  const _TilesRow();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lang = context.watch<LocaleProvider>().code;
    final last = data.lastAttended;
    final unread = data.unread;

    Widget tile({required IconData icon, required Color color, required String title, required String value, required VoidCallback onTap}) {
      return Expanded(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 12.5, color: Brand.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Brand.text, height: 1.3)),
              ]),
            ),
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile(
          icon: Icons.event_available_rounded,
          color: Brand.primary,
          title: context.tr('last_attendance'),
          value: last == null ? context.tr('no_attendance_yet') : '${last.course}\n${formatDay(last.date, lang)}',
          onTap: () => context.read<NavProvider>().go(NavProvider.attendance),
        ),
        const SizedBox(width: 12),
        tile(
          icon: Icons.notifications_rounded,
          color: Brand.accent,
          title: context.tr('nav_notifications'),
          value: unread > 0 ? context.tr('unread_notifications', {'n': unread}) : context.tr('no_unread'),
          onTap: () => context.read<NavProvider>().go(NavProvider.notifications),
        ),
      ]),
    );
  }
}
