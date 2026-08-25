import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'state/app_state.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/setup_wizard.dart';
import 'ui/widgets/dragon_mark.dart';

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
            themeMode: state.ready ? state.settings.theme : ThemeMode.dark,
            builder: (context, child) {
              // keep oversized system font scales from breaking layouts
              final mq = MediaQuery.of(context);
              final clamped = mq.textScaler.scale(100) > 120
                  ? TextScaler.linear(1.2)
                  : mq.textScaler;
              return MediaQuery(
                data: mq.copyWith(textScaler: clamped),
                child: child ?? const SizedBox.shrink(),
              );
            },
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
            const DragonAscii(fontSize: 6.4, softFade: false)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 0.7, end: 1.0, duration: 1400.ms),
            const SizedBox(height: 22),
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
                    DragonMonogram(size: 28),
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
