import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/supabase_service.dart';
import 'models/user_profile.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/main_nav_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CookTalkMobileApp());
  SupabaseService.instance.initialize();
}

// ---------------------------------------------------------------------------
// THEME & PALETTE DEFINITIONS
// Unified 2-Color Brand System:
// - Brand Structure & Headlines: Deep Forest Green (#143826)
// - Interactive Accent: Fresh Mint Lime (#D2E68B)
// --------------------------------------------------------------------------------------------------------------------------

class CookTalkTheme {
  static const primaryAccent = Color(0xFFD2E68B); // Fresh Mint Lime
  static const forestGreen = Color(0xFF143826);   // Deep Forest Green
  static const secondaryAccent = Color(0xFF10B981);
  static const listeningAccent = Color(0xFF10B981);
  static const speakingAccent = Color(0xFF0EA5E9);
  static const timerAccent = primaryAccent;

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    scaffoldBackgroundColor: const Color(0xFF0D0F12),
    colorScheme: const ColorScheme.dark(
      primary: primaryAccent,
      secondary: forestGreen,
      surface: Color(0xFF161920),
      onSurface: Color(0xFFF3F4F6),
      surfaceContainerHighest: Color(0xFF222631),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF161920),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Color(0xFF282E3D), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    ),
    scaffoldBackgroundColor: const Color(0xFFF9FAF7),
    colorScheme: const ColorScheme.light(
      primary: forestGreen,
      secondary: primaryAccent,
      surface: Colors.white,
      onSurface: forestGreen,
      surfaceContainerHighest: Color(0xFFECEFE8),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Color(0xFFECEFE8), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: forestGreen),
      titleTextStyle: TextStyle(
        color: forestGreen,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
    ),
  );
}

// Global theme mode notifier for seamless toggle across all screens
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

class CookTalkMobileApp extends StatelessWidget {
  const CookTalkMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'CookTalk',
          debugShowCheckedModeBanner: false,
          theme: CookTalkTheme.lightTheme,
          darkTheme: CookTalkTheme.darkTheme,
          themeMode: mode,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: SupabaseService.instance.authStateNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return const OnboardingScreen();
        }
        if (!user.onboardingCompleted) {
          return const PreferencesScreen();
        }
        return const MainNavScreen();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// DATA MODELS
// ---------------------------------------------------------------------------

class RecipeItem {
  final String id;
  final String name;
  final String description;
  final int totalSteps;

  const RecipeItem({
    required this.id,
    required this.name,
    required this.description,
    required this.totalSteps,
  });

  factory RecipeItem.fromJson(String id, Map<String, dynamic> json) {
    final steps = json['steps'] as List<dynamic>? ?? [];
    return RecipeItem(
      id: id,
      name: json['name'] as String? ?? id,
      description: json['description'] as String? ?? '',
      totalSteps: steps.length,
    );
  }
}

class PassiveTimer {
  final String label;
  final int durationSeconds;
  final double expiresAtEpochSec;
  bool isCompleted;

  PassiveTimer({
    required this.label,
    required this.durationSeconds,
    required this.expiresAtEpochSec,
    this.isCompleted = false,
  });

  int get remainingSeconds {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final rem = (expiresAtEpochSec - now).ceil();
    return rem > 0 ? rem : 0;
  }
}

enum AgentVoiceState {
  connecting,
  listening,
  speaking,
  error,
}

// ---------------------------------------------------------------------------
// TASK 2: PRE-SESSION SCREEN (TAP-TO-SELECT RECIPE PICKER)
// Deliberate design exception: Tap is permitted BEFORE hands get dirty in the
// kitchen. Starting the session transitions to voice-only operation.
// ---------------------------------------------------------------------------

class PreSessionScreen extends StatefulWidget {
  const PreSessionScreen({super.key});

  @override
  State<PreSessionScreen> createState() => _PreSessionScreenState();
}

class _PreSessionScreenState extends State<PreSessionScreen> {
  late final TextEditingController _serverUrlController;
  List<RecipeItem> _recipes = [];
  String? _selectedRecipeId;
  bool _isLoadingRecipes = true;
  String? _recipeFetchError;

  @override
  void initState() {
    super.initState();
    final defaultHost = Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
    _serverUrlController = TextEditingController(text: defaultHost);
    _loadRecipes();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoadingRecipes = true;
      _recipeFetchError = null;
    });

    try {
      final base = _serverUrlController.text.trim();
      final res = await http.get(Uri.parse('$base/api/recipes')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final list = data.entries.map((e) => RecipeItem.fromJson(e.key, e.value as Map<String, dynamic>)).toList();
        setState(() {
          _recipes = list;
          if (_recipes.isNotEmpty && _selectedRecipeId == null) {
            _selectedRecipeId = _recipes.first.id;
          }
          _isLoadingRecipes = false;
        });
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      // Fallback preset recipes if token server unreachable or booting
      setState(() {
        _recipes = const [
          RecipeItem(
            id: 'scrambled_eggs',
            name: 'Classic French Soft-Curd Scrambled Eggs',
            description: 'Velvety, slow-cooked scrambled eggs with butter and chives.',
            totalSteps: 4,
          ),
          RecipeItem(
            id: 'cacio_e_pepe',
            name: 'Roman Cacio e Pepe',
            description: 'Creamy emulsion of pecorino romano and toasted black pepper.',
            totalSteps: 4,
          ),
          RecipeItem(
            id: 'pan_seared_ribeye',
            name: 'Butter-Basted Cast Iron Ribeye Steak',
            description: 'Hard sear with rosemary, crushed garlic, and butter-basting.',
            totalSteps: 4,
          ),
          RecipeItem(
            id: 'chocolate_chip_cookies',
            name: 'Brown Butter Chocolate Chip Cookies',
            description: 'Nutty brown butter cookies with crisp edges and a gooey center.',
            totalSteps: 4,
          ),
        ];
        _selectedRecipeId ??= 'scrambled_eggs';
        _isLoadingRecipes = false;
        _recipeFetchError = 'Loaded offline recipe catalog ($e)';
      });
    }
  }

  void _cycleTheme() {
    final current = appThemeMode.value;
    if (current == ThemeMode.system) {
      appThemeMode.value = ThemeMode.dark;
    } else if (current == ThemeMode.dark) {
      appThemeMode.value = ThemeMode.light;
    } else {
      appThemeMode.value = ThemeMode.system;
    }
  }

  IconData _getThemeIcon(BuildContext context) {
    final mode = appThemeMode.value;
    if (mode == ThemeMode.dark) return Icons.dark_mode_rounded;
    if (mode == ThemeMode.light) return Icons.light_mode_rounded;
    return Icons.brightness_auto_rounded;
  }

  void _startCookingSession() {
    final selected = _recipes.firstWhere(
      (r) => r.id == _selectedRecipeId,
      orElse: () => _recipes.first,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InSessionScreen(
          serverUrl: _serverUrlController.text.trim(),
          initialRecipe: selected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CookTalkTheme.primaryAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restaurant_rounded, color: CookTalkTheme.primaryAccent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('CookTalk Pre-Session'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Theme (System / Dark / Light)',
            icon: Icon(_getThemeIcon(context)),
            onPressed: _cycleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice Card explaining the deliberate Pre-Session Tap vs In-Session Voice design boundary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2330) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap-to-select is enabled here before your hands get messy. Once session starts, the screen becomes 100% read-only voice-driven.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Server URL Config (accordion-like or compact field)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AGENT TOKEN SERVER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _serverUrlController,
                              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            onPressed: _loadRecipes,
                            tooltip: 'Refresh recipe catalog',
                          ),
                        ],
                      ),
                      if (_recipeFetchError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _recipeFetchError!,
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Recipe Selection Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Recipe to Cook',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_recipes.length} available',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Recipe Cards list (Tap to select)
              if (_isLoadingRecipes)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recipes.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _recipes[index];
                    final isSelected = item.id == _selectedRecipeId;

                    return InkWell(
                      onTap: () => setState(() => _selectedRecipeId = item.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CookTalkTheme.primaryAccent.withValues(alpha: isDark ? 0.15 : 0.08)
                              : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? CookTalkTheme.primaryAccent
                                : (isDark ? const Color(0xFF282E3D) : const Color(0xFFE5E7EB)),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: item.id,
                              groupValue: _selectedRecipeId,
                              activeColor: CookTalkTheme.primaryAccent,
                              onChanged: (val) => setState(() => _selectedRecipeId = val),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF222631) : const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${item.totalSteps} steps',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Start Cooking Button
              ElevatedButton(
                onPressed: _recipes.isEmpty ? null : _startCookingSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CookTalkTheme.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Start Cooking Session',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Hands-Free Voice Co-Pilot • LiveKit + Deepgram + Groq + Rime',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TASK 3: PRIMARY IN-SESSION SCREEN (PASSIVE, VOICE-ONLY REFLECTION)
// Strictly follows the core design constraint:
// - Read-only reflection of state the agent already reached via voice.
// - NO next/prev step buttons, NO tappable ingredients, NO search controls.
// - Populated ONLY from LiveKit data channel events (recipe_state, turn_metrics,
//   timer_started, timer_completed).
// ---------------------------------------------------------------------------

class InSessionScreen extends StatefulWidget {
  final String serverUrl;
  final RecipeItem initialRecipe;

  const InSessionScreen({
    super.key,
    required this.serverUrl,
    required this.initialRecipe,
  });

  @override
  State<InSessionScreen> createState() => _InSessionScreenState();
}

class _InSessionScreenState extends State<InSessionScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  Timer? _countdownTicker;

  // Real voice state from LiveKit events
  AgentVoiceState _voiceState = AgentVoiceState.connecting;
  String _statusLine = 'Connecting to kitchen LiveKit room...';

  // Passive Recipe Card state (from 'recipe_state' data channel packets)
  late String _recipeName;
  int _currentStep = 1;
  late int _totalSteps;
  String _currentInstruction = 'Initializing recipe co-pilot...';

  // Passive Timers (from 'timer_started' & 'timer_completed' packets)
  final List<PassiveTimer> _timers = [];

  // Live Turn Metrics
  String _lastAgentUtterance = 'Connecting to agent...';
  int? _lastTtsTtfbMs;
  int? _lastE2eLatencyMs;

  @override
  void initState() {
    super.initState();
    _recipeName = widget.initialRecipe.name;
    _totalSteps = widget.initialRecipe.totalSteps;
    _startLiveKitSession();

    // 1-second ticker for passive visual timer countdown
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _timers.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _cleanupRoom();
    super.dispose();
  }

  Future<void> _cleanupRoom() async {
    try {
      await _listener?.dispose();
      _listener = null;
      await _room?.disconnect();
      await _room?.dispose();
      _room = null;
    } catch (e) {
      debugPrint('[InSession] Disconnect error: $e');
    }
  }

  Future<void> _startLiveKitSession() async {
    try {
      // 1. Ensure microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        throw Exception('Microphone permission required for hands-free cooking co-pilot.');
      }

      // 2. Fetch JWT room token
      final roomName = 'cooktalk-mobile-${DateTime.now().millisecondsSinceEpoch % 100000}';
      final tokenUri = Uri.parse('${widget.serverUrl}/api/token?room=$roomName&name=MobileChef');
      final res = await http.get(tokenUri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('Token server HTTP ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final String token = data['token'];
      final String livekitUrl = data['url'];

      setState(() {
        _statusLine = 'Joining kitchen WebRTC room...';
      });

      // 3. Connect to LiveKit Room
      const roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions: AudioPublishOptions(
          name: 'microphone',
          dtx: true,
        ),
      );

      final room = Room(roomOptions: roomOptions);
      _room = room;

      final listener = room.createListener();
      _listener = listener;

      _attachLiveKitListeners(listener);

      await room.connect(livekitUrl, token);

      // 4. Publish local microphone
      await room.localParticipant?.setMicrophoneEnabled(true);

      // 5. Send initial recipe selection packet so agent aligns immediately
      try {
        final selectPacket = utf8.encode(jsonEncode({
          'type': 'select_recipe',
          'recipe_id': widget.initialRecipe.id,
        }));
        await room.localParticipant?.publishData(selectPacket);
      } catch (e) {
        debugPrint('[InSession] Initial select_recipe error: $e');
      }

      setState(() {
        _voiceState = AgentVoiceState.listening;
        _statusLine = 'Agent connected • Speak naturally to navigate';
      });
    } catch (e) {
      debugPrint('[InSession] Connection failure: $e');
      setState(() {
        _voiceState = AgentVoiceState.error;
        _statusLine = 'Connection error: $e';
      });
    }
  }

  void _attachLiveKitListeners(EventsListener<RoomEvent> listener) {
    listener
      ..on<RoomDisconnectedEvent>((_) {
        if (!mounted) return;
        setState(() {
          _voiceState = AgentVoiceState.error;
          _statusLine = 'Disconnected from session';
        });
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        if (!mounted) return;
        final room = _room;
        if (room == null) return;

        final isRemoteSpeaking = event.speakers.any((s) => s.sid != room.localParticipant?.sid);
        setState(() {
          if (isRemoteSpeaking) {
            _voiceState = AgentVoiceState.speaking;
            _statusLine = 'Chef CookTalk is speaking...';
          } else {
            if (_voiceState != AgentVoiceState.error && _voiceState != AgentVoiceState.connecting) {
              _voiceState = AgentVoiceState.listening;
              _statusLine = 'Listening hands-free • Say "Next step" or ask anything';
            }
          }
        });
      })
      ..on<DataReceivedEvent>((event) {
        _handleDataPacket(event.data);
      });
  }

  void _handleDataPacket(List<int> rawBytes) {
    try {
      final jsonStr = utf8.decode(rawBytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (!mounted) return;

      setState(() {
        if (type == 'recipe_state') {
          // Passive recipe card sync
          if (data['recipe_name'] != null) _recipeName = data['recipe_name'];
          if (data['current_step'] != null) _currentStep = data['current_step'] as int;
          if (data['total_steps'] != null) _totalSteps = data['total_steps'] as int;
          if (data['instruction'] != null && (data['instruction'] as String).isNotEmpty) {
            _currentInstruction = data['instruction'];
          }
        } else if (type == 'timer_started') {
          // Passive timer sync
          final label = data['label'] as String? ?? 'Cooking Timer';
          final duration = (data['duration_seconds'] as num?)?.toInt() ?? 60;
          final expiresAt = (data['expires_at'] as num?)?.toDouble() ??
              (DateTime.now().millisecondsSinceEpoch / 1000.0 + duration);

          _timers.removeWhere((t) => t.label == label);
          _timers.add(PassiveTimer(
            label: label,
            durationSeconds: duration,
            expiresAtEpochSec: expiresAt,
          ));
        } else if (type == 'timer_completed') {
          final label = data['label'] as String? ?? '';
          for (final t in _timers) {
            if (t.label == label) t.isCompleted = true;
          }
        } else if (type == 'turn_metrics') {
          if (data['agent_response'] != null) {
            _lastAgentUtterance = data['agent_response'];
          }
          if (data['tts_ttfb_ms'] != null) {
            _lastTtsTtfbMs = (data['tts_ttfb_ms'] as num).toInt();
          }
          if (data['latency_ms'] != null) {
            _lastE2eLatencyMs = (data['latency_ms'] as num).toInt();
          }
        }
      });
    } catch (e) {
      debugPrint('[InSession] Error parsing data packet: $e');
    }
  }

  void _cycleTheme() {
    final current = appThemeMode.value;
    if (current == ThemeMode.system) {
      appThemeMode.value = ThemeMode.dark;
    } else if (current == ThemeMode.dark) {
      appThemeMode.value = ThemeMode.light;
    } else {
      appThemeMode.value = ThemeMode.system;
    }
  }

  IconData _getThemeIcon() {
    final mode = appThemeMode.value;
    if (mode == ThemeMode.dark) return Icons.dark_mode_rounded;
    if (mode == ThemeMode.light) return Icons.light_mode_rounded;
    return Icons.brightness_auto_rounded;
  }

  Color _getVoiceStateColor() {
    switch (_voiceState) {
      case AgentVoiceState.connecting:
        return CookTalkTheme.secondaryAccent;
      case AgentVoiceState.listening:
        return CookTalkTheme.listeningAccent;
      case AgentVoiceState.speaking:
        return CookTalkTheme.speakingAccent;
      case AgentVoiceState.error:
        return Colors.redAccent;
    }
  }

  String _getVoiceBadgeLabel() {
    switch (_voiceState) {
      case AgentVoiceState.connecting:
        return 'CONNECTING...';
      case AgentVoiceState.listening:
        return 'LISTENING (MIC ACTIVE)';
      case AgentVoiceState.speaking:
        return 'CHEF SPEAKING';
      case AgentVoiceState.error:
        return 'SESSION ERROR';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stateColor = _getVoiceStateColor();
    final stepProgress = _totalSteps > 0 ? (_currentStep / _totalSteps).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'End session and back',
        ),
        title: const Text('Live Cooking Session'),
        actions: [
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(_getThemeIcon()),
            onPressed: _cycleTheme,
          ),
          IconButton(
            tooltip: 'Hang up session',
            icon: const Icon(Icons.call_end_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. VOICE STATE VISUALIZER (Real session driven, no fake timers)
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stateColor.withValues(alpha: isDark ? 0.12 : 0.10),
                            border: Border.all(
                              color: stateColor.withValues(alpha: _voiceState == AgentVoiceState.speaking ? 0.9 : 0.4),
                              width: _voiceState == AgentVoiceState.speaking ? 4 : 2,
                            ),
                          ),
                        ),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stateColor.withValues(alpha: isDark ? 0.25 : 0.18),
                          ),
                          child: Icon(
                            _voiceState == AgentVoiceState.speaking
                                ? Icons.volume_up_rounded
                                : (_voiceState == AgentVoiceState.listening
                                    ? Icons.mic_rounded
                                    : Icons.mic_none_rounded),
                            size: 46,
                            color: stateColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Voice State Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: stateColor, width: 1),
                      ),
                      child: Text(
                        _getVoiceBadgeLabel(),
                        style: TextStyle(
                          color: stateColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      _statusLine,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. PASSIVE RECIPE CARD (Read-only, synchronized from agent data channel)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _recipeName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: CookTalkTheme.primaryAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Step $_currentStep of $_totalSteps',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: CookTalkTheme.primaryAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: stepProgress,
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0xFF282E3D) : const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation<Color>(CookTalkTheme.primaryAccent),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'CURRENT INSTRUCTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentInstruction,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. PASSIVE TIMER CARD (Populated only from timer_started/timer_completed)
              if (_timers.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_rounded, color: CookTalkTheme.timerAccent, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Active Timers',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              'Voice-driven',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._timers.map((t) {
                          final rem = t.remainingSeconds;
                          final mins = rem ~/ 60;
                          final secs = rem % 60;
                          final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
                          final isDone = t.isCompleted || rem == 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? (isDark ? const Color(0xFF2E1C1A) : const Color(0xFFFEF2F2))
                                  : (isDark ? const Color(0xFF24221A) : const Color(0xFFFFFBEB)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDone
                                    ? Colors.redAccent.withValues(alpha: 0.4)
                                    : CookTalkTheme.timerAccent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isDone ? Icons.alarm_on_rounded : Icons.hourglass_top_rounded,
                                      size: 18,
                                      color: isDone ? Colors.redAccent : CookTalkTheme.timerAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      t.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isDone ? Colors.redAccent : null,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  isDone ? 'READY!' : timeStr,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: isDone ? Colors.redAccent : CookTalkTheme.timerAccent,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 4. LIVE SPOKEN UTTERANCE & LATENCY HUD
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'LAST AGENT UTTERANCE',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                          if (_lastTtsTtfbMs != null || _lastE2eLatencyMs != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_lastTtsTtfbMs != null)
                                  Text(
                                    'TTS: ${_lastTtsTtfbMs}ms',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: CookTalkTheme.speakingAccent,
                                    ),
                                  ),
                                if (_lastTtsTtfbMs != null && _lastE2eLatencyMs != null)
                                  const Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                if (_lastE2eLatencyMs != null)
                                  Text(
                                    'E2E: ${_lastE2eLatencyMs}ms',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: CookTalkTheme.primaryAccent,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"$_lastAgentUtterance"',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // READ-ONLY FOOTER ENFORCING DESIGN BOUNDARY
              Center(
                child: Text(
                  'Hands-Free Only • Say "Next step", "Repeat step", or "Set a timer"',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
