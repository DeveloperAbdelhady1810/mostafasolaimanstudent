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
import 'providers/ack_provider.dart';
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
import 'services/reply_scanner.dart';
import 'services/tick_player.dart';
import 'services/secure_store.dart';
import 'services/social_auth_service.dart';
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
    this.replyScanner,
    this.tickPlayer,
    this.social,
  });

  final LocaleProvider locale;
  final bool firebaseReady;

  // Injectable for tests.
  final ApiClient? api;
  final SecureStore? store;
  final Stream<List<ConnectivityResult>>? connectivity;
  final BleAdvertiser? advertiser;
  final ReplyScanner? replyScanner;
  final TickPlayer? tickPlayer;
  final SocialAuth? social;

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
  late final AckProvider ack;
  final nav = NavProvider();

  @override
  void initState() {
    super.initState();
    api = widget.api ?? ApiClient();
    store = widget.store ?? SecureStore();
    auth = AuthProvider(api, store, social: widget.social);
    data = DataProvider(api, store, connectivity: widget.connectivity);
    push = PushService(api);
    code = CodeProvider(auth);
    broadcast = BroadcastProvider(auth, advertiser: widget.advertiser);
    ack = AckProvider(auth, scanner: widget.replyScanner, player: widget.tickPlayer);
    // Listen for the assistant's Bluetooth reply exactly while this phone is broadcasting (listening
    // starts BEFORE the first packet is sent, so an immediate reply is never missed).
    broadcast.onBeforeStart = () => ack.setListening(true);
    broadcast.onStopped = () => unawaited(ack.setListening(false));

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
    push.onMessage = (message) {
      if (!auth.isLoggedIn) return;
      unawaited(data.refreshNotifications());
      unawaited(data.refreshAttendance());
      if (message['type'] == 'attendance_confirmed') unawaited(ack.recorded());
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
    ack.dispose();
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
        ChangeNotifierProvider<AckProvider>.value(value: ack),
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
