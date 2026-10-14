import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum SocialProvider { google, apple }

/// What the provider's own sign-in sheet gave us. The server verifies it; the app never trusts it.
class SocialIdentity {
  const SocialIdentity({required this.provider, required this.token, this.nonce, this.name});

  final SocialProvider provider;

  /// Google: the ID token. Apple: the identity token.
  final String token;

  /// Apple only: the un-hashed nonce (the token carries its SHA-256, so a stolen token cannot be replayed).
  final String? nonce;

  /// Apple only gives the name the first time the person authorises the app.
  final String? name;
}

enum SocialFailure { cancelled, unavailable, failed }

class SocialAuthException implements Exception {
  const SocialAuthException(this.kind, [this.detail]);

  final SocialFailure kind;
  final String? detail;

  @override
  String toString() => 'SocialAuthException($kind${detail != null ? ': $detail' : ''})';
}

/// The phone's native Google / Apple sign-in, behind a seam so the flow can be tested without real accounts.
abstract class SocialAuth {
  /// Sign in with Apple is offered on iPhones (App Store rule 4.8 asks for it next to Google).
  bool get appleAvailable;

  Future<SocialIdentity> google({required String serverClientId});
  Future<SocialIdentity> apple();
}

class PlatformSocialAuth implements SocialAuth {
  bool _googleReady = false;

  @override
  bool get appleAvailable => Platform.isIOS;

  @override
  Future<SocialIdentity> google({required String serverClientId}) async {
    try {
      final google = GoogleSignIn.instance;
      if (!_googleReady) {
        // serverClientId = the WEB client the server verifies tokens for. The iOS client id comes from Info.plist.
        await google.initialize(serverClientId: serverClientId);
        _googleReady = true;
      }

      final account = await google.authenticate();
      final idToken = account.authentication.idToken;

      // Forget the Google session on this phone: our own login is the session, and the next tap
      // should offer the account chooser again.
      try {
        await google.signOut();
      } catch (_) {}

      if (idToken == null || idToken.isEmpty) {
        throw const SocialAuthException(SocialFailure.failed, 'no id token');
      }
      return SocialIdentity(provider: SocialProvider.google, token: idToken);
    } on SocialAuthException {
      rethrow;
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          throw const SocialAuthException(SocialFailure.cancelled);
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw SocialAuthException(SocialFailure.unavailable, e.description);
        default:
          throw SocialAuthException(SocialFailure.failed, '${e.code}: ${e.description}');
      }
    } catch (e) {
      throw SocialAuthException(SocialFailure.failed, e.toString());
    }
  }

  @override
  Future<SocialIdentity> apple() async {
    try {
      final rawNonce = _randomNonce();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );

      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        throw const SocialAuthException(SocialFailure.failed, 'no identity token');
      }
      final name = [credential.givenName, credential.familyName].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      return SocialIdentity(provider: SocialProvider.apple, token: token, nonce: rawNonce, name: name.isEmpty ? null : name);
    } on SocialAuthException {
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          throw const SocialAuthException(SocialFailure.cancelled);
        case AuthorizationErrorCode.notHandled:
        case AuthorizationErrorCode.invalidResponse:
          throw SocialAuthException(SocialFailure.unavailable, e.message);
        default:
          throw SocialAuthException(SocialFailure.failed, '${e.code}: ${e.message}');
      }
    } catch (e) {
      throw SocialAuthException(SocialFailure.failed, e.toString());
    }
  }

  static String _randomNonce([int length = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
