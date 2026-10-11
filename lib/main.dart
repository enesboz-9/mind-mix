import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_settings.dart';
import 'core/audio_service.dart';
import 'core/theme.dart';
import 'home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  await AppSettings.instance.load();
  runApp(const MindMixApp());
}

class MindMixApp extends StatefulWidget {
  const MindMixApp({super.key});

  @override
  State<MindMixApp> createState() => _MindMixAppState();
}

class _MindMixAppState extends State<MindMixApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Uygulama arka plana gidince müziği duraklat, dönünce devam ettir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = AudioService.instance;
    if (state == AppLifecycleState.resumed) {
      if (AppSettings.instance.musicOn && audio.hasStarted) audio.playMusic();
    } else {
      audio.pauseMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: AppSettings.instance,
      child: Builder(
        builder: (context) {
          final t = SettingsScope.of(context).t;
          return MaterialApp(
            title: t.appName,
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
