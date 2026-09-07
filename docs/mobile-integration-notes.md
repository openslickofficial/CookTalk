# CookTalk Mobile Integration Notes (Phase M1)

This document captures the verified SDK requirements, native platform configurations, and connection architecture for integrating the official LiveKit Flutter SDK (`livekit_client`) into CookTalk.

---

## 1. SDK Specifications & Dependencies

- **Package**: `livekit_client` (Official non-beta Flutter SDK)
- **Pub.dev target**: `^2.11.0` (or latest stable matching Flutter 3.x / Dart 3.x)
- **Accompanying Dependencies**:
  - `http: ^1.2.0` (for token retrieval from `token_server.py`)
  - `permission_handler: ^11.3.0` (for explicit runtime mic permission checks)

---

## 2. Platform Permission & Manifest Requirements

### Android Configuration (`android/app/src/main/AndroidManifest.xml`)
The following permissions are required for WebRTC audio capture, network communication, and hardware audio management:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

- **Network Security Configuration**: For local development on emulator (`http://10.0.2.2:8000`) or physical device (`http://<LAN_IP>:8000`), cleartext HTTP traffic must be permitted:
  ```xml
  <application
      android:usesCleartextTraffic="true"
      ... >
  ```
- **Minimum SDK version**: Android API 21+ (`minSdkVersion = 21` or `24` in `android/app/build.gradle`).

### iOS Configuration (`ios/Runner/Info.plist`)
The following keys are required for microphone capture and background audio processing:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>CookTalk needs microphone access for hands-free culinary voice navigation.</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

---

## 3. Recommended LiveKit Room Connection Pattern

The official non-beta LiveKit Flutter client uses the `Room` object lifecycle:

```dart
import 'package:livekit_client/livekit_client.dart';

// 1. Instantiate Room
final room = Room(
  roomOptions: const RoomOptions(
    adaptiveStream: true,
    defaultAudioPublishOptions: AudioPublishOptions(
      name: 'microphone',
      dtx: true,
    ),
  ),
);

// 2. Attach Event Listener
late final EventsListener<RoomEvent> listener = room.createListener();

listener
  ..on<RoomDisconnectedEvent>((e) {
    print('Disconnected from room: ${e.reason}');
  })
  ..on<ActiveSpeakersChangedEvent>((e) {
    // Detect speaking state
    final isAgentSpeaking = e.speakers.any((s) => s.identity.contains('agent'));
  })
  ..on<TrackSubscribedEvent>((e) {
    if (e.track is RemoteAudioTrack) {
      print('Subscribed to remote audio track: ${e.track.sid}');
      // Audio playback is handled automatically by LiveKit Flutter WebRTC engine
    }
  });

// 3. Connect to LiveKit Room
await room.connect(
  livekitUrl,
  token,
  fastConnectOptions: FastConnectOptions(
    microphone: const TrackOption(enabled: true),
  ),
);

// 4. Enable / Publish Local Microphone
await room.localParticipant?.setMicrophoneEnabled(true);

// 5. Clean Disconnect on Exit
await listener.dispose();
await room.disconnect();
```

---

## 4. Token & Network Topology

- **Token Server**: Reuses `web/token_server.py` running on `http://127.0.0.1:8000`.
- **Android Emulator Address**: Accesses host machine via `http://10.0.2.2:8000/api/token?room=...`.
- **Physical Device / Desktop**: Accesses via local network IP or localhost.
