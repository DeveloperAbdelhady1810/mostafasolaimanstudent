import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/providers/auth_provider.dart';
import 'package:student/services/api_client.dart';
import 'package:student/services/secure_store.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Future<AuthProvider> _signedIn(List<http.Request> log, http.Response Function(http.Request) deleteReply) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final api = ApiClient(client: MockClient((r) async {
    log.add(r);
    if (r.url.path.endsWith('/student/account/delete')) return deleteReply(r);
    return _json({'message': 'ok'});
  }));
  final store = SecureStore();
  final auth = AuthProvider(api, store);
  api.token = 'tok';
  await store.write(SecureStore.kToken, 'tok');
  auth.status = AuthStatus.loggedIn;
  return auth;
}

void main() {
  test('delete account: calls the endpoint with the token, then signs this phone out and clears storage', () async {
    final log = <http.Request>[];
    final auth = await _signedIn(log, (_) => _json({'message': 'Your account has been deleted.'}));

    await auth.deleteAccount();

    final del = log.firstWhere((r) => r.url.path.endsWith('/student/account/delete'));
    expect(del.method, 'POST');
    expect(del.headers['Authorization'], 'Bearer tok');
    expect(auth.status, AuthStatus.loggedOut);
    expect(auth.api.token, isNull);
    expect(await auth.store.read(SecureStore.kToken), isNull);
    expect(auth.sessionExpired, isFalse);
  });

  test('delete account: offline leaves the student signed in and throws', () async {
    final log = <http.Request>[];
    final auth = await _signedIn(log, (_) => throw http.ClientException('no network'));

    await expectLater(auth.deleteAccount(), throwsA(isA<ApiException>()));
    expect(auth.status, AuthStatus.loggedIn);
    expect(auth.api.token, 'tok');
  });

  test('delete account: a server error keeps the session', () async {
    final log = <http.Request>[];
    final auth = await _signedIn(log, (_) => _json({'message': 'boom'}, 500));

    await expectLater(auth.deleteAccount(), throwsA(isA<ApiException>()));
    expect(auth.status, AuthStatus.loggedIn);
  });
}
