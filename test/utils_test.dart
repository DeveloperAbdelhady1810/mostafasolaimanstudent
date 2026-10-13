import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:student/utils.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  test('server timestamps without a zone are UTC', () {
    final t = parseServerTime('2026-10-13 16:52:45')!;
    expect(t.toUtc(), DateTime.utc(2026, 10, 13, 16, 52, 45));
  });

  test('ISO timestamps with Z or an offset are respected', () {
    expect(parseServerTime('2026-10-13T16:52:45Z')!.toUtc(), DateTime.utc(2026, 10, 13, 16, 52, 45));
    expect(parseServerTime('2026-10-13T19:52:45+03:00')!.toUtc(), DateTime.utc(2026, 10, 13, 16, 52, 45));
  });

  test('empty or invalid values give null', () {
    expect(parseServerTime(null), isNull);
    expect(parseServerTime(''), isNull);
    expect(parseServerTime('not a date'), isNull);
  });

  test('formatDay handles date-only and date-time values', () {
    expect(formatDay('2026-10-01', 'en'), 'Oct 1, 2026');
    expect(formatDay('2026-10-01T00:00:00.000000Z', 'en'), 'Oct 1, 2026');
    expect(formatDay(null, 'en'), '');
  });
}
