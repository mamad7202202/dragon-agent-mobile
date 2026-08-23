import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'state/app_state.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/setup_wizard.dart';
import 'ui/widgets/flame_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: DragonColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error');
    return true;
  };
  ErrorWidget.builder = (details) => _FatalErrorScreen(details: details);

  runApp(const DragonAgentApp());
}

class DragonAgentApp extends StatelessWidget {
  const DragonAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Dragon Agent',
            debugShowCheckedModeBanner: false,
            theme: buildDragonTheme(Brightness.light),
            darkTheme: buildDragonTheme(Brightness.dark),
            themeMode: ThemeMode.dark,
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: !state.ready
                  ? const _Splash(key: ValueKey('splash'))
                  : state.configured
                      ? const HomeShell(key: ValueKey('home'))
                      : const SetupWizard(key: ValueKey('setup')),
            ),
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DragonColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlameLogo(size: 84)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1.04, 1.04),
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 20),
            Text('Dragon Agent',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(color: DragonColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of the default grey/white error box in release builds.
class _FatalErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;
  const _FatalErrorScreen({required this.details});

  @override
  Widget build(BuildContext context) {
    final msg = details.exception.toString();
    final clipped = msg.length > 700 ? '${msg.substring(0, 700)}…' : msg;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildDragonTheme(Brightness.dark),
      home: Scaffold(
        backgroundColor: DragonColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: DragonColors.ember, size: 28),
                    SizedBox(width: 10),
                    Text('Dragon hit an error',
                        style: TextStyle(
                            color: DragonColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Please report this — the details below help fix it fast.',
                  style: TextStyle(
                      color: DragonColors.textDim, fontSize: 12.5, height: 1.5),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DragonColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DragonColors.stroke),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        clipped,
                        style: TextStyle(
                            color: DragonColors.textDim,
                            fontSize: 11.5,
                            height: 1.5,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
