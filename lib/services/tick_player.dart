import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// The short "success" chime + a haptic tick. Failures are swallowed: a missing audio device must never
/// break the screen.
abstract class TickPlayer {
  Future<void> play();
}

class AssetTickPlayer implements TickPlayer {
  AudioPlayer? _player;

  @override
  Future<void> play() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
    try {
      _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await _player!.stop();
      await _player!.play(AssetSource('sounds/tick.wav'), volume: 1.0);
    } catch (_) {}
  }
}
