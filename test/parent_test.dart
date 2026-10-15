import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/l10n/strings.dart';
import 'package:student/main.dart';
import 'package:student/models.dart';
import 'package:student/providers/locale_provider.dart';
import 'package:student/services/api_client.dart';
import 'package:student/services/secure_store.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Future<void> _pump(WidgetTester tester, [int frames = 15]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> _parentUser({bool must = false}) => {
      'id': 70,
      'name': 'Mona Parent',
      'email': 'parent_x@mostafasoliman.temp',
      'phone': '01142877525',
      'role': 'parent',
      'student_number': null,
      'avatar': null,
      'must_change_password': must,
    };

const _children = {
  'children': [
    {
      'id': 5, 'name': 'Omar Kid', 'student_number': 10001, 'grade': 'تالتة ثانوي - ثانوي', 'study_mode': 'online',
      'center': null, 'present': 3, 'absent': 1, 'courses': 2, 'progress': 40, 'last_attended': '2026-10-12',
    },
    {
      'id': 6, 'name': 'Sara Kid', 'student_number': 10002, 'grade': 'تانية ثانوي - ثانوي', 'study_mode': 'center',
      'center': 'Nasr City', 'present': 0, 'absent': 0, 'courses': 0, 'progress': 0, 'last_attended': null,
    },
  ],
};

Future<void> _boot(WidgetTester tester, MockClient client, {String lang = 'en'}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StudentApp(
    locale: LocaleProvider(lang),
    api: ApiClient(client: client),
    store: SecureStore(),
    connectivity: Stream.value([ConnectivityResult.wifi]),
  ));
  await _pump(tester);
}

MockClient _server(List<String> seen, {bool must = false}) => MockClient((req) async {
      seen.add('${req.method} ${req.url.path}');
      final p = req.url.path;
      if (p.endsWith('/auth/student-login')) {
        return _json({'token': 'ptok', 'user': _parentUser(must: must), 'server_time': DateTime.now().millisecondsSinceEpoch ~/ 1000});
      }
      if (p.endsWith('/parent/change-password')) {
        final b = jsonDecode(req.body) as Map;
        if (b['current_password'] != 'Initial-1') {
          return _json({'message': 'x', 'errors': {'current_password': ['The current password is not correct.']}}, 422);
        }
        return _json({'message': 'Password changed.'});
      }
      if (p.endsWith('/parent/children')) return _json(_children);
      if (p.endsWith('/parent/children/5/attendance')) {
        return _json({
          'records': [
            {'id': 1, 'course': 'Algebra', 'center': null, 'date': '2026-10-12', 'status': 'present', 'scanned_at': null},
            {'id': 2, 'course': 'Geometry', 'center': null, 'date': '2026-10-05', 'status': 'absent', 'scanned_at': null},
          ]
        });
      }
      if (p.endsWith('/parent/children/5/courses')) {
        return _json({
          'courses': [
            {'id': 9, 'title': 'Calculus term 1', 'subject': 'math', 'lectures_total': 10, 'lectures_done': 4, 'progress': 40}
          ],
          'quizzes_taken': 3,
          'quizzes_passed': 2,
        });
      }
      if (p.endsWith('/parent/notifications')) {
        return _json([
          {'id': 1, 'type': 'child_present', 'title': 'Omar Kid attended', 'body': 'Algebra', 'read_at': null, 'created_at': '2026-10-12 18:30:00'}
        ]);
      }
      return _json({'message': 'ok'});
    });

void main() {
  test('English and Arabic have exactly the same keys', () {
    expect(appStrings['en']!.keys.toSet(), appStrings['ar']!.keys.toSet());
  });

  test('StudentUser keeps the role and the forced-password flag through storage', () {
    final u = StudentUser.fromJson(_parentUser(must: true));
    expect(u.isParent, isTrue);
    expect(u.mustChangePassword, isTrue);
    final back = StudentUser.fromJson(u.toJson());
    expect(back.isParent && back.mustChangePassword, isTrue);
    expect(StudentUser.fromJson({'id': 1, 'name': 'S'}).isParent, isFalse);
  });

  testWidgets('parent signs in and sees only the parent app with the children', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final seen = <String>[];
    await _boot(tester, _server(seen));

    await tester.enterText(find.byType(TextFormField).at(0), '01142877525');
    await tester.enterText(find.byType(TextFormField).at(1), 'Pass-1234');
    await tester.tap(find.text('Sign In'));
    await _pump(tester, 25);

    expect(find.text('Omar Kid'), findsOneWidget);
    expect(find.text('Sara Kid'), findsOneWidget);
    expect(find.text('Hello Mona Parent'), findsOneWidget);
    expect(find.byKey(const Key('student_id_text')), findsNothing, reason: 'a parent has no student ID/QR');
    expect(seen, contains('GET /api/parent/children'));
    expect(seen, contains('GET /api/parent/notifications'));
    expect(seen.any((s) => s.contains('/student/')), isFalse, reason: 'no student endpoints for a parent');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a child opens to attendance and course progress', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'token': 'ptok', 'user': jsonEncode(_parentUser())});
    final seen = <String>[];
    await _boot(tester, _server(seen));

    await tester.tap(find.text('Omar Kid'));
    await _pump(tester, 20);
    expect(find.text('Algebra'), findsOneWidget);
    expect(find.text('Geometry'), findsOneWidget);
    expect(find.text('Absent'), findsWidgets);

    await tester.tap(find.text('Courses').last);
    await _pump(tester, 10);
    expect(find.text('Calculus term 1'), findsOneWidget);
    expect(find.text('Quizzes passed: 2 of 3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('first-login parent must choose a password before seeing anything', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'token': 'ptok', 'user': jsonEncode(_parentUser(must: true))});
    final seen = <String>[];
    await _boot(tester, _server(seen, must: true));

    expect(find.text('Choose your password'), findsWidgets);
    expect(find.text('Omar Kid'), findsNothing);

    // wrong current password -> the server's message, still locked
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'nope');
    await tester.enterText(fields.at(1), 'Brand-New-9');
    await tester.enterText(fields.at(2), 'Brand-New-9');
    await tester.tap(find.text('Save'));
    await _pump(tester, 15);
    expect(find.text('The current password is not correct.'), findsOneWidget);
    expect(find.text('Omar Kid'), findsNothing);

    // mismatch is caught before any request
    await tester.enterText(fields.at(0), 'Initial-1');
    await tester.enterText(fields.at(2), 'different');
    await tester.tap(find.text('Save'));
    await _pump(tester, 5);
    expect(find.text("Passwords don't match"), findsOneWidget);

    await tester.enterText(fields.at(2), 'Brand-New-9');
    await tester.tap(find.text('Save'));
    await _pump(tester, 25);
    expect(find.text('Omar Kid'), findsOneWidget);
    expect(seen.where((s) => s == 'POST /api/parent/change-password').length, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline: the last known children list is still shown', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'token': 'ptok',
      'user': jsonEncode(_parentUser()),
      'cache_children': jsonEncode(_children['children']),
    });
    await _boot(tester, MockClient((r) async => throw http.ClientException('no network')));
    expect(find.text('Omar Kid'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Arabic labels for the parent app', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'token': 'ptok', 'user': jsonEncode(_parentUser())});
    await _boot(tester, _server([]), lang: 'ar');
    expect(find.text('أبنائي'), findsWidgets);
    expect(find.text('أهلاً Mona Parent'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
