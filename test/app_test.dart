import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:student/main.dart';
import 'package:student/providers/auth_provider.dart';
import 'package:student/providers/code_provider.dart';
import 'package:student/providers/locale_provider.dart';
import 'package:student/services/api_client.dart';
import 'package:student/services/secure_store.dart';

final _secretBytes = Uint8List.fromList(List<int>.generate(32, (i) => i));

Map<String, String> _signedInStore({bool withSecret = true}) => {
      'token': 'stored-token',
      'user': jsonEncode({
        'id': 5,
        'name': 'Omar Tester',
        'email': 'omar@example.com',
        'phone': '01012345678',
        'student_number': 10001,
        'avatar': null,
      }),
      if (withSecret) 'secret': base64Encode(_secretBytes),
      'cache_attendance': jsonEncode([
        {'id': 1, 'course': 'Algebra 1', 'center': 'Nasr City', 'date': '2026-10-01', 'status': 'present', 'scanned_at': null},
        {'id': 2, 'course': 'Algebra 2', 'center': 'Nasr City', 'date': '2026-10-08', 'status': 'absent', 'scanned_at': null},
      ]),
    };

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Future<void> _pump(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _boot(
  WidgetTester tester, {
  required MockClient client,
  String lang = 'en',
  Stream<List<ConnectivityResult>>? connectivity,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(StudentApp(
    locale: LocaleProvider(lang),
    api: ApiClient(client: client),
    store: SecureStore(),
    connectivity: connectivity ?? Stream.value([ConnectivityResult.wifi]),
  ));
  await _pump(tester);
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox()); // disposes providers + the 1 s code timer
}

void main() {
  testWidgets('restores a signed-in student with NO network and shows ID + rotating QR', (tester) async {
    FlutterSecureStorage.setMockInitialValues(_signedInStore());
    final client = MockClient((req) async => throw const SocketException('no route'));

    await _boot(tester, client: client);

    expect(find.text('Sign In'), findsNothing, reason: 'must not ask to log in again');
    expect(find.byKey(const Key('student_id_text')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('student_id_text'))).data, '10001');
    expect(find.byKey(const Key('qr_code')), findsOneWidget);
    expect(find.text('Secure code'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text("You're offline - your code still works."), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('offline: cached attendance is still shown', (tester) async {
    FlutterSecureStorage.setMockInitialValues(_signedInStore());
    final client = MockClient((req) async => throw const SocketException('no route'));

    await _boot(tester, client: client);
    await tester.tap(find.text('Attendance').last);
    await _pump(tester);

    expect(find.text('Algebra 1'), findsOneWidget);
    expect(find.text('Algebra 2'), findsOneWidget);
    expect(find.text('1 of 2 sessions attended'), findsOneWidget);
    expect(find.textContaining('Showing saved data'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('without the secret the app falls back to the plain ID code', (tester) async {
    FlutterSecureStorage.setMockInitialValues(_signedInStore(withSecret: false));
    final client = MockClient((req) async => _json({'message': 'Bluetooth attendance is not enabled yet.'}, 403));

    await _boot(tester, client: client);

    expect(find.text('ID code'), findsOneWidget);
    expect(find.byKey(const Key('qr_code')), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('login with valid credentials opens the app', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final seen = <String>[];
    final client = MockClient((req) async {
      seen.add('${req.method} ${req.url.path}');
      if (req.url.path.endsWith('/auth/student-login')) {
        final body = jsonDecode(req.body) as Map;
        expect(body['login'], 'omar@example.com');
        expect(body['password'], 'secret123');
        return _json({
          'token': 'fresh-token',
          'user': {'id': 5, 'name': 'Omar Tester', 'email': 'omar@example.com', 'phone': null, 'role': 'student', 'student_number': 10001, 'avatar': null},
          'server_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });
      }
      if (req.url.path.endsWith('/student/ble/secret')) return _json({'message': 'not enabled'}, 403);
      if (req.url.path.endsWith('/student/attendance')) {
        return _json({
          'records': [
            {'id': 9, 'course': 'Geometry', 'center': null, 'date': '2026-10-12', 'status': 'present', 'scanned_at': null}
          ]
        });
      }
      if (req.url.path.endsWith('/notifications')) {
        return _json([
          {'id': 1, 'type': 'attendance_confirmed', 'title': 'Attendance recorded', 'body': 'Geometry - 18:30', 'read_at': null, 'created_at': '2026-10-12 18:30:00'}
        ]);
      }
      return _json({'message': 'ok'});
    });

    await _boot(tester, client: client);

    expect(find.text('Welcome Back'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'omar@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Sign In'));
    await _pump(tester, 20);

    expect(find.byKey(const Key('student_id_text')), findsOneWidget);
    expect(find.text('Hello, Omar'), findsOneWidget);
    expect(find.text('ID code'), findsOneWidget); // secret endpoint said "not enabled yet"
    expect(seen, contains('POST /api/auth/student-login'));
    expect(find.text('1 unread'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('login with wrong password shows the error and stays on the login page', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = MockClient((req) async => _json({'message': 'These credentials do not match our records.'}, 401));

    await _boot(tester, client: client);
    await tester.enterText(find.byType(TextFormField).at(0), 'omar@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.text('Sign In'));
    await _pump(tester);

    expect(find.text('These credentials do not match our records.'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('login with no internet explains it needs a connection', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = MockClient((req) async => throw const SocketException('no route'));

    await _boot(tester, client: client);
    await tester.enterText(find.byType(TextFormField).at(0), '01012345678');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Sign In'));
    await _pump(tester);

    expect(find.text('No internet connection. Please connect and try again.'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('Arabic: right-to-left layout and Arabic texts', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = MockClient((req) async => throw const SocketException('no route'));

    await _boot(tester, client: client, lang: 'ar');

    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('أهلاً بعودتك')));
    expect(dir, TextDirection.rtl);

    await _teardown(tester);
  });

  testWidgets('switching language on the login page flips direction', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = MockClient((req) async => throw const SocketException('no route'));

    await _boot(tester, client: client);
    expect(Directionality.of(tester.element(find.text('Welcome Back'))), TextDirection.ltr);

    await tester.tap(find.text('عربي'));
    await _pump(tester);

    expect(find.text('أهلاً بعودتك'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('أهلاً بعودتك'))), TextDirection.rtl);

    await _teardown(tester);
  });

  testWidgets('a revoked token (401) signs the student out with a message', (tester) async {
    FlutterSecureStorage.setMockInitialValues(_signedInStore());
    final client = MockClient((req) async => _json({'message': 'Unauthenticated.'}, 401));

    await _boot(tester, client: client);

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Your session expired. Please sign in again.'), findsOneWidget);

    await _teardown(tester);
  });

  test('CodeProvider produces the rotating payload from the stored secret, offline', () async {
    FlutterSecureStorage.setMockInitialValues(_signedInStore());
    final api = ApiClient(client: MockClient((req) async => throw const SocketException('x')));
    final auth = AuthProvider(api, SecureStore());
    await auth.restore();

    final now = 59000000 * 30 + 7;
    final code = CodeProvider(auth, clock: () => now);
    expect(code.payload, 'MSQ1:10001:59000000:b4a0fdce853f03dfc5');
    expect(code.secondsLeft, 23);
    expect(code.isRotating, isTrue);
    code.dispose();
  });
}
