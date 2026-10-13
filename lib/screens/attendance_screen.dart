import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/data_provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final lang = context.watch<LocaleProvider>().code;
    final records = data.attendance;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('attendance_title'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: RefreshIndicator(
        color: Brand.primary,
        onRefresh: data.refreshAttendance,
        child: records.isEmpty
            ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: data.attendanceLoading
                      ? const Center(child: CircularProgressIndicator(color: Brand.primary))
                      : EmptyState(
                          icon: Icons.event_busy_rounded,
                          title: context.tr('attendance_empty'),
                          note: context.tr('attendance_empty_note'),
                        ),
                ),
              ])
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: records.length + 2,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == 0) return _Summary(present: data.presentCount, total: records.length);
                  if (i == records.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        [
                          if (data.attendanceFromCache || data.offline) context.tr('saved_data'),
                          if (data.attendanceUpdatedAt != null)
                            context.tr('updated_at', {'time': formatDateTime(data.attendanceUpdatedAt, lang)}),
                        ].join(' - '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Brand.muted),
                      ),
                    );
                  }
                  return _RecordTile(record: records[i - 1], lang: lang);
                },
              ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.present, required this.total});
  final int present;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : present / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: Brand.gradient, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: ratio,
              strokeWidth: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.28),
              color: Colors.white,
            ),
            Text('${(ratio * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            context.tr('present_of', {'p': present, 't': total}),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
          ),
        ),
      ]),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.lang});
  final AttendanceRecord record;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final ok = record.isPresent;
    final color = ok ? Brand.primary : Brand.danger;
    final sub = [
      if (record.center != null && record.center!.isNotEmpty) record.center!,
      formatDay(record.date, lang),
    ].where((s) => s.isNotEmpty).join(' - ');

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
            Text(record.course, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Brand.text)),
            const SizedBox(height: 3),
            Text(sub, style: const TextStyle(fontSize: 12.5, color: Brand.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(context.tr(ok ? 'present' : 'absent'), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
