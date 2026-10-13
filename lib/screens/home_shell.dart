import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ack_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/nav_provider.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'attendance_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

/// Shows the splash, the login page or the app depending on the stored session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    switch (context.watch<AuthProvider>().status) {
      case AuthStatus.loading:
        return const _Splash();
      case AuthStatus.loggedOut:
        return const LoginScreen();
      case AuthStatus.loggedIn:
        return const HomeShell();
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Image.asset('assets/logo.png', width: 220)),
      );
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavProvider>();
    final unread = context.select<DataProvider, int>((d) => d.unread);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: nav.index,
            children: const [
              HomeScreen(),
              AttendanceScreen(),
              NotificationsScreen(),
              SettingsScreen(),
            ],
          ),
          const _AckBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.index,
        onDestinationSelected: nav.go,
        height: 68,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: context.tr('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_available_outlined),
            selectedIcon: const Icon(Icons.event_available_rounded),
            label: context.tr('nav_attendance'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: Brand.danger,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              backgroundColor: Brand.danger,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: context.tr('nav_notifications'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: context.tr('nav_settings'),
          ),
        ],
      ),
    );
  }
}

/// "Assistant scanned you successfully" - slides in over any tab when the assistant's phone heard this
/// phone over Bluetooth (works offline) or the server recorded the attendance.
class _AckBanner extends StatelessWidget {
  const _AckBanner();

  @override
  Widget build(BuildContext context) {
    final kind = context.watch<AckProvider>().banner;
    final text = kind == null ? '' : context.tr(kind == AckKind.heard ? 'ack_heard' : 'ack_recorded');

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: kind == null
              ? const SizedBox.shrink(key: ValueKey('no_ack'))
              : Padding(
                  key: ValueKey('ack_$kind'),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: GestureDetector(
                    onTap: context.read<AckProvider>().dismiss,
                    child: Material(
                      key: const Key('ack_banner'),
                      elevation: 8,
                      color: Brand.primary,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(children: [
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(text,
                                style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
