import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/main.dart';
import 'package:student/providers/locale_provider.dart';
import 'package:student/services/api_client.dart';
import 'package:student/services/secure_store.dart';
import 'package:student/services/social_auth_service.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

class FakeSocial implements SocialAuth {
  FakeSocial({this.appleAvailable = false});

  @override
  bool appleAvailable;

  SocialIdentity? googleIdentity = const SocialIdentity(provider: SocialProvider.google, token: 'google-id-token');
  SocialIdentity? appleIdentity =
      const SocialIdentity(provider: SocialProvider.apple, token: 'apple-token', nonce: 'raw-nonce', name: 'Sara Apple');
  SocialAuthException? googleError;
  SocialAuthException? appleError;
  String? lastServerClientId;
  int googleCalls = 0;
  int appleCalls = 0;

  @override
  Future<SocialIdentity> google({required String serverClientId}) async {
    googleCalls++;
    lastServerClientId = serverClientId;
    if (googleError != null) throw googleError!;
    return googleIdentity!;
  }

  @override
  Future<SocialIdentity> apple() async {
    appleCalls++;
    if (appleError != null) throw appleError!;
    return appleIdentity!;
  }
}

const _loginOk = {
  'token': 'tok-social',
  'user': {
    'id': 9, 'name': 'Omar Social', 'email': 'omar@gmail.com', 'phone': '01012345678',
    'role': 'student', 'student_number': 10590, 'avatar': null,
  },
  'server_time': 1791900000,
};

const _options = {
  'stages': [
    {
      'key': 'preparatory', 'name_ar': 'اعدادي',
      'grades': [
        {'key': 'grade_3', 'name_ar': 'تالتة اعدادي', 'divisions': []},
      ],
    },
    {
      'key': 'secondary', 'name_ar': 'ثانوي',
      'grades': [
        {
          'key': 'grade_3', 'name_ar': 'تالتة ثانوي',
          'divisions': [
            {'key': 'math', 'name_ar': 'علمي رياضة'},
            {'key': 'literary', 'name_ar': 'ادبي'},
          ],
        },
      ],
    },
  ],
  'study_modes': ['center', 'online', 'zoom'],
  'zoom_groups': [
    {'id': 4, 'name': 'Group A'},
  ],
};

class Harness {
  Harness({this.social}) {
    social ??= FakeSocial();
  }

  FakeSocial? social;
  final List<http.Request> requests = [];

  Map<String, dynamic> config = {'google_enabled': true, 'google_server_client_id': 'web-client-id', 'apple_enabled': true};
  http.Response Function(http.Request)? onGoogle;
  http.Response Function(http.Request)? onApple;
  http.Response Function(http.Request)? onComplete;

  http.Request? last(String suffix) => requests.where((r) => r.url.path.endsWith(suffix)).lastOrNull;
  Map<String, dynamic> bodyOf(String suffix) => jsonDecode(last(suffix)!.body) as Map<String, dynamic>;

  http.Response handle(http.Request r) {
    requests.add(r);
    final path = r.url.path;
    if (path.endsWith('/auth/social/config')) return _json(config);
    if (path.endsWith('/auth/social/options')) return _json(_options);
    if (path.endsWith('/auth/social/google')) return (onGoogle ?? (_) => _json(_loginOk))(r);
    if (path.endsWith('/auth/social/apple')) return (onApple ?? (_) => _json(_loginOk))(r);
    if (path.endsWith('/auth/social/complete')) return (onComplete ?? (_) => _json(_loginOk, 201))(r);
    if (path.endsWith('/student/ble/secret')) return _json({'message': 'not enabled'}, 403);
    if (path.endsWith('/student/attendance')) return _json({'records': []});
    if (path.endsWith('/notifications')) return _json([]);
    return _json({'message': 'ok'});
  }
}

Map<String, dynamic> _needsProfile({String name = 'Omar Social'}) =>
    {'needs_profile': true, 'ticket': 'ticket-123', 'email': 'omar@gmail.com', 'name': name};

Future<void> _pump(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _boot(WidgetTester tester, Harness h, {String lang = 'en'}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(StudentApp(
    locale: LocaleProvider(lang),
    api: ApiClient(client: MockClient((r) async => h.handle(r))),
    store: SecureStore(),
    social: h.social,
    connectivity: Stream.value([]),
  ));
  await _pump(tester);
}

Future<void> _teardown(WidgetTester tester) async => tester.pumpWidget(const SizedBox());

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await _pump(tester, 6);
}

Future<void> _pick(WidgetTester tester, Key field, String itemText) async {
  await _tap(tester, find.byKey(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemText).last);
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmitProfile(WidgetTester tester, {String? phone, String? parentPhone}) async {
  await tester.enterText(find.byKey(const Key('f_phone')), phone ?? '01012345678');
  await tester.enterText(find.byKey(const Key('f_parent_phone')), parentPhone ?? '01112345678');
  await _pick(tester, const Key('f_stage'), 'ثانوي  -  Secondary');
  await _pick(tester, const ValueKey('f_grade_secondary'), 'تالتة ثانوي');
  await _pick(tester, const ValueKey('f_division_secondary_grade_3'), 'علمي رياضة');
  await _tap(tester, find.text('Online'));
  await tester.enterText(find.byKey(const Key('f_school')), 'Cairo Language School');
  await _tap(tester, find.text('Male'));
  await tester.enterText(find.byKey(const Key('f_age')), '17');
  await _tap(tester, find.byKey(const Key('f_submit')));
  await _pump(tester, 15);
}

void main() {
  group('buttons', () {
    testWidgets('Google is always offered; Apple only on iPhone', (tester) async {
      final h = Harness(social: FakeSocial(appleAvailable: false));
      await _boot(tester, h);
      expect(find.byKey(const Key('google_button')), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byKey(const Key('apple_button')), findsNothing);
      await _teardown(tester);

      final ios = Harness(social: FakeSocial(appleAvailable: true));
      await _boot(tester, ios);
      expect(find.byKey(const Key('apple_button')), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('Arabic labels', (tester) async {
      final h = Harness(social: FakeSocial(appleAvailable: true));
      await _boot(tester, h, lang: 'ar');
      expect(find.text('المتابعة باستخدام جوجل'), findsOneWidget);
      expect(find.text('المتابعة باستخدام Apple'), findsOneWidget);
      expect(find.text('أو تابع باستخدام'), findsOneWidget);
      await _teardown(tester);
    });
  });

  group('Google', () {
    testWidgets('existing student: asks the server for its client id, sends only the token, lands in the app', (tester) async {
      final h = Harness();
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 15);

      expect(h.social!.lastServerClientId, 'web-client-id');
      expect(h.bodyOf('/auth/social/google'), {'id_token': 'google-id-token'});
      expect(find.byKey(const Key('student_id_text')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('student_id_text'))).data, '10590');
      expect(find.text('Welcome Back'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('cancelling the Google sheet is silent', (tester) async {
      final h = Harness();
      h.social!.googleError = const SocialAuthException(SocialFailure.cancelled);
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('google_button')));

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.textContaining('did not complete'), findsNothing);
      expect(h.last('/auth/social/google'), isNull, reason: 'nothing is sent to the server');
      await _teardown(tester);
    });

    testWidgets('Google not set up on the server: clear message, Google SDK never opened', (tester) async {
      final h = Harness();
      h.config = {'google_enabled': false, 'google_server_client_id': null, 'apple_enabled': true};
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('google_button')));

      expect(find.text('This sign-in method is not available on this phone right now.'), findsOneWidget);
      expect(h.social!.googleCalls, 0);
      await _teardown(tester);
    });

    testWidgets('a Google failure on the phone shows a retry message', (tester) async {
      final h = Harness();
      h.social!.googleError = const SocialAuthException(SocialFailure.failed, 'boom');
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('google_button')));

      expect(find.text('Sign-in did not complete. Please try again.'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('server refuses a non-student email', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json({'code': 'not_student', 'message': 'This email belongs to a different kind of account.'}, 403);
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 10);

      expect(find.text('This email belongs to a different kind of account. Please use the website for it.'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('server could not verify the token (401)', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json({'code': 'bad_audience', 'message': 'x'}, 401);
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 10);

      expect(find.text('Sign-in could not be verified. Please try again.'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('no internet', (tester) async {
      final h = Harness();
      await tester.runAsync(() async {});
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(StudentApp(
        locale: LocaleProvider('en'),
        api: ApiClient(client: MockClient((r) async => throw http.ClientException('offline'))),
        store: SecureStore(),
        social: h.social,
        connectivity: Stream.value([]),
      ));
      await _pump(tester);

      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 10);

      expect(find.text('No internet connection. Please connect and try again.'), findsOneWidget);
      await _teardown(tester);
    });
  });

  group('new account -> profile form', () {
    testWidgets('unknown email opens the form prefilled; submitting creates the account and signs in', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json(_needsProfile());
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 15);

      expect(find.text('Complete your profile'), findsOneWidget);
      expect(find.text('omar@gmail.com'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byKey(const Key('f_name'))).controller!.text, 'Omar Social');
      // choices come from the server; divisions/zoom group only appear when relevant
      expect(find.byKey(const ValueKey('f_division_null_null')), findsNothing);
      expect(find.byKey(const Key('f_zoom_group')), findsNothing);

      await _fillAndSubmitProfile(tester);

      final body = h.bodyOf('/auth/social/complete');
      expect(body['ticket'], 'ticket-123');
      expect(body['name'], 'Omar Social');
      expect(body['phone'], '01012345678');
      expect(body['parent_phone'], '01112345678');
      expect(body['education_stage'], 'secondary');
      expect(body['grade'], 'grade_3');
      expect(body['division'], 'math');
      expect(body['study_mode'], 'online');
      expect(body.containsKey('zoom_group_id'), isFalse);
      expect(body['school'], 'Cairo Language School');
      expect(body['gender'], 'male');
      expect(body['age'], 17);

      // signed in, and the profile page is gone
      expect(find.byKey(const Key('student_id_text')), findsOneWidget);
      expect(find.text('Complete your profile'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('a grade without divisions shows no division field; zoom shows the group picker', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json(_needsProfile());
      await _boot(tester, h);
      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 15);

      await _pick(tester, const Key('f_stage'), 'اعدادي  -  Preparatory');
      await _pick(tester, const ValueKey('f_grade_preparatory'), 'تالتة اعدادي');
      expect(find.byKey(const ValueKey('f_division_preparatory_grade_3')), findsNothing);

      await _tap(tester, find.text('Zoom'));
      expect(find.byKey(const Key('f_zoom_group')), findsOneWidget);
      await _pick(tester, const Key('f_zoom_group'), 'Group A');

      await tester.enterText(find.byKey(const Key('f_phone')), '01012345678');
      await tester.enterText(find.byKey(const Key('f_parent_phone')), '01112345678');
      await tester.enterText(find.byKey(const Key('f_school')), 'School');
      await _tap(tester, find.text('Female'));
      await tester.enterText(find.byKey(const Key('f_age')), '14');
      await _tap(tester, find.byKey(const Key('f_submit')));
      await _pump(tester, 15);

      final body = h.bodyOf('/auth/social/complete');
      expect(body['study_mode'], 'zoom');
      expect(body['zoom_group_id'], 4);
      expect(body.containsKey('division'), isFalse);
      expect(body['gender'], 'female');
      await _teardown(tester);
    });

    testWidgets('empty form: required messages, nothing is sent', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json(_needsProfile());
      await _boot(tester, h);
      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 15);

      await _tap(tester, find.byKey(const Key('f_submit')));

      expect(find.text('This field is required'), findsWidgets);
      expect(h.last('/auth/social/complete'), isNull);
      await _teardown(tester);
    });

    testWidgets('age outside 10-30 is refused before sending', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json(_needsProfile());
      await _boot(tester, h);
      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 15);

      await tester.enterText(find.byKey(const Key('f_age')), '9');
      await _tap(tester, find.byKey(const Key('f_submit')));

      expect(find.text('Enter an age between 10 and 30'), findsOneWidget);
      expect(h.last('/auth/social/complete'), isNull);
      await _teardown(tester);
    });

    testWidgets('server validation messages appear under the right field and clear when edited', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json(_needsProfile());
      h.onComplete = (_) => _json({
            'message': 'The phone has already been taken.',
            'errors': {
              'phone': ['The phone has already been taken.'],
              'parent_phone': ['Parent phone number must be different from your own phone number.'],
            },
          }, 422);
      await _boot(tester, h);
      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 15);

      await _fillAndSubmitProfile(tester);

      expect(find.text('The phone has already been taken.'), findsOneWidget);
      expect(find.text('Parent phone number must be different from your own phone number.'), findsOneWidget);
      expect(find.text('Complete your profile'), findsOneWidget, reason: 'stays on the form');

      await tester.enterText(find.byKey(const Key('f_phone')), '01099999999');
      await tester.pump();
      expect(find.text('The phone has already been taken.'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('expired sign-in (410) tells the student to start again', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json(_needsProfile());
      h.onComplete = (_) => _json({'code': 'ticket_expired', 'message': 'Your sign-in expired.'}, 410);
      await _boot(tester, h);
      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 15);

      await _fillAndSubmitProfile(tester);

      expect(find.text('Your sign-in expired. Please try again.'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('options cannot be loaded: retry button', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json(_needsProfile());
      var fail = true;
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(StudentApp(
        locale: LocaleProvider('en'),
        api: ApiClient(client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/social/options') && fail) return _json({'message': 'down'}, 500);
          return h.handle(r);
        })),
        store: SecureStore(),
        social: h.social,
        connectivity: Stream.value([]),
      ));
      await _pump(tester);
      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 15);

      expect(find.text("Couldn't load the form. Check your connection and try again."), findsOneWidget);

      fail = false;
      await _tap(tester, find.text('Retry'));
      await _pump(tester, 10);
      expect(find.byKey(const Key('f_phone')), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('profile form works in Arabic (right to left)', (tester) async {
      final h = Harness();
      h.onGoogle = (_) => _json(_needsProfile());
      await _boot(tester, h, lang: 'ar');
      await _tap(tester, find.byKey(const Key('google_button')));
      await _pump(tester, 15);

      expect(find.text('أكمل بياناتك'), findsOneWidget);
      expect(find.text('إنشاء حسابي'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('أكمل بياناتك'))), TextDirection.rtl);
      await _teardown(tester);
    });
  });

  group('Apple', () {
    testWidgets('existing student: sends identity token + nonce + name, lands in the app', (tester) async {
      final h = Harness(social: FakeSocial(appleAvailable: true));
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('apple_button')));
      await _pump(tester, 15);

      expect(h.bodyOf('/auth/social/apple'), {'identity_token': 'apple-token', 'nonce': 'raw-nonce', 'name': 'Sara Apple'});
      expect(find.byKey(const Key('student_id_text')), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('new Apple account: the name Apple gave prefills the form', (tester) async {
      final h = Harness(social: FakeSocial(appleAvailable: true));
      h.onApple = (_) => _json(_needsProfile(name: 'Sara Apple'));
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('apple_button')));
      await _pump(tester, 15);

      expect(find.text('Complete your profile'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byKey(const Key('f_name'))).controller!.text, 'Sara Apple');
      await _teardown(tester);
    });

    testWidgets('cancelled Apple sheet is silent; nothing sent', (tester) async {
      final h = Harness(social: FakeSocial(appleAvailable: true));
      h.social!.appleError = const SocialAuthException(SocialFailure.cancelled);
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('apple_button')));

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(h.last('/auth/social/apple'), isNull);
      await _teardown(tester);
    });

    testWidgets('Apple shared no email -> explains what to do', (tester) async {
      final h = Harness(social: FakeSocial(appleAvailable: true));
      h.onApple = (_) => _json({'code': 'no_email', 'message': 'No email address was shared by the provider.'}, 422);
      await _boot(tester, h);

      await _tap(tester, find.byKey(const Key('apple_button')));
      await _pump(tester, 10);

      expect(find.text('No email address was shared. Please allow sharing your email and try again.'), findsOneWidget);
      await _teardown(tester);
    });
  });
}
