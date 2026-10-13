import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';

/// English / Arabic switch (Arabic flips the whole app to right-to-left).
class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._code, [SharedPreferences? prefs]) : _prefs = prefs;

  static const _key = 'lang';

  String _code;
  final SharedPreferences? _prefs;

  static Future<LocaleProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final device = ui.PlatformDispatcher.instance.locale.languageCode;
    return LocaleProvider(saved ?? (device == 'ar' ? 'ar' : 'en'), prefs);
  }

  String get code => _code;
  bool get isArabic => _code == 'ar';
  Locale get locale => Locale(_code);

  Future<void> setLanguage(String code) async {
    if (code == _code || !appStrings.containsKey(code)) return;
    _code = code;
    notifyListeners();
    await _prefs?.setString(_key, code);
  }

  /// Looks up [key]; `{name}`-style placeholders are replaced from [args].
  String t(String key, [Map<String, Object?>? args]) {
    var s = appStrings[_code]?[key] ?? appStrings['en']![key] ?? key;
    args?.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
    return s;
  }
}
