import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'data/database.dart'; import 'providers/business_provider.dart'; import 'ui/app.dart'; import 'app_profile.dart';
const supabaseUrl=String.fromEnvironment('SUPABASE_URL'); const supabasePublishableKey=String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
Future<void> main() async { AppProfile.current = AppProfile.admin; WidgetsFlutterBinding.ensureInitialized(); await JustAudioBackground.init(androidNotificationChannelId: 'com.gajurmukhi.music', androidNotificationChannelName: 'Gajurmukhi Music', androidNotificationOngoing: true); final supabaseEnabled = supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty; if (supabaseEnabled) { await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey); } final db = AppDatabase(); await db.init(); runApp(ChangeNotifierProvider(create: (_) => BusinessProvider(db)..bootstrap(), child: GajurmukhiApp(supabaseEnabled: supabaseEnabled))); }
