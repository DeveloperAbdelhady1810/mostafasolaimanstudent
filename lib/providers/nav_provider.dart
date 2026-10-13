import 'package:flutter/foundation.dart';

/// Which bottom tab is showing; lets a tapped push notification jump to the right one.
class NavProvider extends ChangeNotifier {
  static const home = 0;
  static const attendance = 1;
  static const notifications = 2;
  static const settings = 3;

  int index = home;

  void go(int i) {
    if (i == index) return;
    index = i;
    notifyListeners();
  }
}
