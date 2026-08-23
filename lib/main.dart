import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
      systemNavigationBarColor: Colors.transparent,
    ),
  );
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
            builder: (context, child) {
              final base = Theme.of(context);
              final withFont = base.copyWith(
                textTheme: GoogleFonts.interTextTheme(base.textTheme),
              );
              return DefaultTextStyle(
                style: withFont.textTheme.bodyMedium!,
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
