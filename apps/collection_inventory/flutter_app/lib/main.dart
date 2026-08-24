import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app_profile.dart';
import 'services/ai_command_service.dart';
import 'data/database.dart';
import 'providers/business_provider.dart';
import 'ui/app.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppProfile.current = AppProfile.store;
  runApp(const _BootstrapApp());
}

Future<_BootstrapResult> _bootstrap() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.gajurmukhi.music',
      androidNotificationChannelName: 'Gajurmukhi Music',
      androidNotificationOngoing: true,
    );
  } catch (_) {}

  var supabaseEnabled = false;
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
      supabaseEnabled = true;
    } catch (_) {}
  }

  await AppSettingsService.load();
  final db = AppDatabase();
  await db.init();
  return _BootstrapResult(db: db, supabaseEnabled: supabaseEnabled);
}

class _BootstrapResult {
  final AppDatabase db;
  final bool supabaseEnabled;
  const _BootstrapResult({required this.db, required this.supabaseEnabled});
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();
  @override State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<_BootstrapResult> future = _bootstrap();

  @override
  Widget build(BuildContext context) => FutureBuilder<_BootstrapResult>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _StartupFailure(error: snapshot.error.toString());
          if (!snapshot.hasData) return const _StartupLoading();
          final result = snapshot.data!;
          return ChangeNotifierProvider(
            create: (_) => BusinessProvider(result.db)..bootstrap(),
            child: GajurmukhiApp(supabaseEnabled: result.supabaseEnabled),
          );
        },
      );
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
}

class _StartupFailure extends StatelessWidget {
  final String error;
  const _StartupFailure({required this.error});
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Gajurmukhi Store could not start', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('Please close and reopen the app. If this continues, send this diagnostic message to support.', textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  SelectableText(error, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
}
