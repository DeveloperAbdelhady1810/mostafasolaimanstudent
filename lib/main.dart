import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'l10n/strings.dart';
import 'providers/auth_provider.dart';
import 'providers/broadcast_provider.dart';
import 'providers/code_provider.dart';
import 'providers/data_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/nav_provider.dart';
import 'screens/home_shell.dart';
import 'services/api_client.dart';
import 'services/ble_advertiser.dart';
import 'services/push_service.dart';
import 'services/secure_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  // A phone without Google services must still open the app (push is optional).
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: AppFirebaseOptions.current);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase unavailable: $e');
  }

  final locale = await LocaleProvider.load();
  runApp(StudentApp(locale: locale, firebaseReady: firebaseReady));
}

class StudentApp extends StatefulWidget {
  const StudentApp({
    super.key,
    required this.locale,
    this.firebaseReady = false,
    this.api,
    this.store,
    this.connectivity,
    this.advertiser,
  });

  final LocaleProvider locale;
  final bool firebaseReady;

  // Injectable for tests.
  final ApiClient? api;
  final SecureStore? store;
  final Stream<List<ConnectivityResult>>? connectivity;
  final BleAdvertiser? advertiser;

  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> with WidgetsBindingObserver {
  late final ApiClient api;
  late final SecureStore store;
  late final AuthProvider auth;
  late final DataProvider data;
  late final PushService push;
  late final CodeProvider code;
  late final BroadcastProvider broadcast;
  final nav = NavProvider();

  @override
  void initState() {
    super.initState();
    api = widget.api ?? ApiClient();
    store = widget.store ?? SecureStore();
    auth = AuthProvider(api, store);
    data = DataProvider(api, store, connectivity: widget.connectivity);
    push = PushService(api);
    code = CodeProvider(auth);
    broadcast = BroadcastProvider(auth, advertiser: widget.advertiser);

    auth.onSignedIn = _onSignedIn;
    auth.onBeforeSignOut = () async {
      await push.unregister();
      data.reset();
      nav.go(NavProvider.home);
    };
    data.onBackOnline = () {
      if (!auth.isLoggedIn) return;
      unawaited(auth.refreshSecret());
      unawaited(data.syncAll());
      unawaited(push.register());
    };
    push.onMessage = () {
      if (!auth.isLoggedIn) return;
      unawaited(data.refreshNotifications());
      unawaited(data.refreshAttendance());
    };
    push.onOpen = () {
      nav.go(NavProvider.notifications);
      if (auth.isLoggedIn) unawaited(data.refreshNotifications());
    };

    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  DateTime _lastResumeSync = DateTime.fromMillisecondsSinceEpoch(0);

  /// Coming back to the app: pick up anything that arrived while it was in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      broadcast.onBackground();
      return;
    }
    if (state != AppLifecycleState.resumed || !auth.isLoggedIn) return;
    broadcast.onForeground();
    final now = DateTime.now();
    if (now.difference(_lastResumeSync).inSeconds < 20) return;
    _lastResumeSync = now;
    unawaited(data.syncAll());
  }

  Future<void> _boot() async {
    // Session first: the ID and code must appear without waiting for Firebase.
    await auth.restore();
    await push.init(firebaseReady: widget.firebaseReady);
    if (auth.isLoggedIn && push.permitted) unawaited(push.register());
  }

  Future<void> _onSignedIn(bool fresh) async {
    await data.loadCache(); // shows the last known lists instantly, even offline
    unawaited(auth.refreshSecret());
    unawaited(data.syncAll());
    if (push.permitted) {
      unawaited(push.register());
    } else if (fresh) {
      // Ask once, right after a real sign-in. The Bluetooth prompt waits its turn: two system
      // permission dialogs at the same time make Android drop one of them.
      broadcast.holdAutoStart = true;
      try {
        await push.enable();
      } finally {
        broadcast.holdAutoStart = false;
      }
      broadcast.onForeground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    broadcast.dispose();
    code.dispose();
    data.dispose();
    push.dispose();
    auth.dispose();
    nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: widget.locale),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<DataProvider>.value(value: data),
        ChangeNotifierProvider<PushService>.value(value: push),
        ChangeNotifierProvider<CodeProvider>.value(value: code),
        ChangeNotifierProvider<BroadcastProvider>.value(value: broadcast),
        ChangeNotifierProvider<NavProvider>.value(value: nav),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, lp, _) => MaterialApp(
          title: appStrings['en']!['app_name']!,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: lp.locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthGate(),
        ),
      ),
    );
  }
}
