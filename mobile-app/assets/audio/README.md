# Audio Assets for PantryPilot

## Timer Alarm Audio

Place a short alarm sound file here:

**File name:** `alarm.mp3`

**Recommendations:**
- Duration: 1–3 seconds (short burst or loop)
- Format: MP3, WAV, or OGG
- Codec: AAC or MP3 for best compatibility
- Level: ~-6dB to avoid clipping

### Getting an Alarm Sound

Option 1: Use a royalty-free alarm clip
- Freesound.org (search for "alarm beep")
- Zapsplat.com (search for "timer alarm")
- OpenGameArt.org

Option 2: Generate programmatically
- Audacity (open source) - generate a sine wave tone
- GarageBand or Ableton Live - create a simple beep pattern

Option 3: Use your system's default alarm
- The app includes vibration + notification sound fallback, so if no MP3 is present,
  the device's default notification/alarm tone will play via the notification system.

### Testing

After adding `alarm.mp3`:
1. Rebuild the app: `flutter pub get && flutter run`
2. In Guided Cooking screen, start a step timer and let it reach 0:00
3. You should hear the alarm sound + feel vibration (if device supports it)
4. If the app is backgrounded, you'll see a notification with sound/vibration
