import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import '../theme.dart';

extension TrContext on BuildContext {
  /// Translate and rebuild when the language changes (use inside build()).
  String tr(String key, [Map<String, Object?>? args]) => watch<LocaleProvider>().t(key, args);

  /// Translate once (use inside callbacks).
  String trRead(String key, [Map<String, Object?>? args]) => read<LocaleProvider>().t(key, args);
}

/// EN | AR pill.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    Widget chip(String code, String label) {
      final selected = lp.code == code;
      return GestureDetector(
        onTap: () => lp.setLanguage(code),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? (onDark ? Colors.white : Brand.primary) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? (onDark ? Brand.primaryDark : Colors.white) : (onDark ? Colors.white : Brand.muted),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.18) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: onDark ? null : Border.all(color: Brand.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        chip('en', 'EN'),
        chip('ar', 'عربي'),
      ]),
    );
  }
}

/// Emerald gradient button, like the website's primary buttons.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(14);
    return Container(
      decoration: BoxDecoration(
        gradient: enabled || loading ? Brand.buttonGradient : null,
        color: enabled || loading ? null : Brand.border,
        borderRadius: radius,
        boxShadow: enabled || loading
            ? [BoxShadow(color: Brand.primary.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
          ),
        ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded, size: 18, color: Brand.warning),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.note});
  final IconData icon;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: Brand.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: Brand.primary),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Brand.text)),
          const SizedBox(height: 8),
          Text(note, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5, color: Brand.muted)),
        ]),
      ),
    );
  }
}

/// White rounded card used across screens.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}
