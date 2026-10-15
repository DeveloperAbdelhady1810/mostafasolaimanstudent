import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_client.dart';
import '../services/social_auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'complete_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  /// Which social button is waiting for the provider / server (null = none).
  SocialProvider? _socialBusy;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  String _messageFor(ApiException e) {
    if (e.isOffline) return context.trRead('err_network');
    switch (e.status) {
      case 401:
        return context.trRead('err_invalid_credentials');
      case 403:
        return e.code == 'two_factor_required' ? context.trRead('err_two_factor') : context.trRead('err_blocked');
      case 409:
        return context.trRead('err_profile_incomplete');
      case 429:
        return context.trRead('err_too_many');
      default:
        return context.trRead('err_generic');
    }
  }

  String _socialMessageFor(ApiException e) {
    if (e.isOffline) return context.trRead('err_network');
    switch (e.status) {
      case 401:
        return context.trRead('err_social_rejected');
      case 403:
        return context.trRead(e.code == 'not_student' ? 'err_not_student' : 'err_blocked');
      case 410:
        return context.trRead('err_social_expired');
      case 422:
        return context.trRead(e.code == 'no_email' ? 'err_no_email' : 'err_social_rejected');
      case 429:
        return context.trRead('err_too_many');
      case 503:
        return context.trRead('err_social_not_ready');
      default:
        return context.trRead('err_generic');
    }
  }

  Future<void> _social(SocialProvider provider) async {
    if (_busy || _socialBusy != null) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    setState(() {
      _socialBusy = provider;
      _error = null;
    });
    try {
      final pending = await auth.socialLogin(provider);
      // Signed in: AuthGate swaps this page for the app. Otherwise the email has no student account yet.
      if (pending != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CompleteProfileScreen(pending: pending)));
      }
    } on SocialAuthException catch (e) {
      if (e.kind != SocialFailure.cancelled) debugPrint('Social sign-in: $e');
      if (mounted && e.kind != SocialFailure.cancelled) {
        setState(() => _error = context.trRead(e.kind == SocialFailure.unavailable ? 'err_social_unavailable' : 'err_social_failed'));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _socialMessageFor(e));
    } catch (e) {
      debugPrint('Social sign-in failed: $e');
      if (mounted) setState(() => _error = context.trRead('err_social_failed'));
    } finally {
      if (mounted) setState(() => _socialBusy = null);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(_login.text, _password.text);
      // AuthGate swaps to the home shell as soon as the status flips.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } catch (_) {
      if (mounted) setState(() => _error = context.trRead('err_generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = context.select<AuthProvider, bool>((a) => a.sessionExpired);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          // Brand header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: Brand.gradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 56),
                child: Column(children: [
                  const Align(alignment: AlignmentDirectional.centerEnd, child: LanguageToggle(onDark: true)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: Image.asset('assets/logo.png', height: 82),
                  ),
                ]),
              ),
            ),
          ),

          // Form card overlapping the header
          Transform.translate(
            offset: const Offset(0, -34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _form,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(context.tr('login_title'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Brand.text)),
                      const SizedBox(height: 4),
                      Text(context.tr('login_subtitle'), style: const TextStyle(fontSize: 14, color: Brand.muted)),
                      const SizedBox(height: 2),
                      Text(context.tr('login_parent_hint'), style: const TextStyle(fontSize: 12.5, color: Brand.muted)),
                      const SizedBox(height: 20),
                      if (expired) ...[
                        OfflineBanner(text: context.tr('session_expired')),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _login,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: context.tr('login_field'),
                          hintText: context.tr('login_field_hint'),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? context.trRead('field_required') : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _hide,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        textDirection: TextDirection.ltr,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: context.tr('password'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? context.trRead('field_required') : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Brand.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Brand.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: Brand.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: const TextStyle(color: Brand.danger, fontSize: 13.5, fontWeight: FontWeight.w600))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 20),
                      GradientButton(label: context.tr('sign_in'), loading: _busy, onPressed: _socialBusy != null ? null : _submit),
                      const SizedBox(height: 20),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(context.tr('or_continue_with'),
                              style: const TextStyle(fontSize: 12.5, color: Brand.muted, fontWeight: FontWeight.w600)),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 14),
                      _GoogleButton(
                        label: context.tr('continue_google'),
                        loading: _socialBusy == SocialProvider.google,
                        onPressed: (_busy || _socialBusy != null) ? null : () => _social(SocialProvider.google),
                      ),
                      if (context.read<AuthProvider>().appleAvailable) ...[
                        const SizedBox(height: 12),
                        _AppleButton(
                          loading: _socialBusy == SocialProvider.apple,
                          text: context.read<LocaleProvider>().isArabic ? 'المتابعة باستخدام Apple' : 'Continue with Apple',
                          onPressed: (_busy || _socialBusy != null) ? null : () => _social(SocialProvider.apple),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.wifi_rounded, size: 16, color: Brand.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(context.tr('login_needs_internet'),
                              style: const TextStyle(fontSize: 12.5, height: 1.45, color: Brand.muted)),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(children: [
              Text(context.tr('no_account'), style: const TextStyle(color: Brand.muted, fontSize: 13.5)),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('$siteUrl/register/student'), mode: LaunchMode.externalApplication),
                child: Text(context.tr('signup_web'), style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.primaryDark)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}


class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        key: const Key('google_button'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Brand.text,
          side: const BorderSide(color: Brand.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.primary))
            : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Image.asset('assets/google_g.png', width: 22, height: 22),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                ),
              ]),
      ),
    );
  }
}

/// Apple's own button style (black, Apple logo) as their design guidelines require.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.loading, required this.text, required this.onPressed});

  final bool loading;
  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        key: const Key('apple_button'),
        height: 52,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
      );
    }
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: IgnorePointer(
        ignoring: onPressed == null,
        child: SignInWithAppleButton(
          key: const Key('apple_button'),
          onPressed: onPressed ?? () {},
          text: text,
          height: 52,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          style: SignInWithAppleButtonStyle.black,
        ),
      ),
    );
  }
}
