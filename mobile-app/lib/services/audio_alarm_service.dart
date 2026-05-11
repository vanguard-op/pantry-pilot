import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

/// Handles timer completion alarms with both audio and haptic feedback.
///
/// Provides consistent alarm behavior across Android, iOS, and desktop:
/// - Foreground: plays bundled audio asset + vibration pattern
/// - Can integrate with local notifications for background fallback
class AudioAlarmService {
  AudioAlarmService() : _audioPlayer = AudioPlayer();

  final AudioPlayer _audioPlayer;
  static const String _alarmAssetPath = 'assets/audio/alarm.mp3';

  /// Initialize audio resources. Call during app startup.
  Future<void> initialize() async {
    try {
      await _audioPlayer.setAsset(_alarmAssetPath);
      await _audioPlayer.setLoopMode(LoopMode.off);
    } catch (e) {
      // Asset not found; audio playback will be skipped but alarm() will still vibrate.
      print('AudioAlarmService: Failed to load alarm asset - $e');
    }
  }

  /// Play timer completion alarm with audio + vibration.
  ///
  /// Foreground behavior:
  /// - Plays bundled alarm.mp3 if available
  /// - Triggers haptic feedback (vibration pattern)
  ///
  /// Recommended to call this when [CookingState.secondsRemaining] reaches 0.
  Future<void> alarm() async {
    try {
      // Trigger vibration pattern: 200ms on, 100ms off, 200ms on, 100ms off, 200ms on
      await _vibrate();
      // Play audio (if asset is loaded)
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } catch (e) {
      print('AudioAlarmService: Error playing alarm - $e');
    }
  }

  Future<void> _vibrate() async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) {
      return;
    }

    // Pattern: 200ms vibrate, 100ms pause, 200ms vibrate, 100ms pause, 200ms vibrate
    const pattern = [0, 200, 100, 200, 100, 200];
    try {
      await Vibration.vibrate(pattern: pattern);
    } catch (e) {
      print('AudioAlarmService: Vibration failed - $e');
    }
  }

  /// Clean up audio resources.
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
