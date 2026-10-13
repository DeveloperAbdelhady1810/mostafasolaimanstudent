import 'package:intl/intl.dart';

/// The server stores and returns times in UTC without a zone marker
/// ("2026-10-13 16:52:45"); parse them as UTC and convert to the phone's local time.
DateTime? parseServerTime(String? s) {
  if (s == null || s.isEmpty) return null;
  final iso = s.contains('T') ? s : s.replaceFirst(' ', 'T');
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(iso);
  return DateTime.tryParse(hasZone ? iso : '${iso}Z')?.toLocal();
}

/// "yyyy-MM-dd[...]" -> "12 Oct 2026" / "١٢ أكتوبر ٢٠٢٦" in the app language.
String formatDay(String? ymd, String lang) {
  if (ymd == null || ymd.length < 10) return ymd ?? '';
  final d = DateTime.tryParse(ymd.substring(0, 10));
  if (d == null) return ymd;
  try {
    return DateFormat.yMMMd(lang).format(d);
  } catch (_) {
    return ymd.substring(0, 10);
  }
}

String formatDateTime(DateTime? t, String lang) {
  if (t == null) return '';
  try {
    return DateFormat.MMMd(lang).add_jm().format(t);
  } catch (_) {
    return t.toIso8601String();
  }
}
