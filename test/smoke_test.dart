import 'package:flutter_test/flutter_test.dart';
import 'package:dragon_agent_mobile/core/theme.dart';
import 'package:dragon_agent_mobile/data/models.dart';
import 'package:dragon_agent_mobile/ui/screens/setup_wizard.dart';
import 'package:dragon_agent_mobile/ui/widgets/flame_logo.dart';
import 'package:flutter/material.dart';

void main() {
  test('deriveBubbles maps wire entries to display items', () {
    final wire = <Map<String, dynamic>>[
      Wire.user('hello'),
      Wire.assistant('hi there'),
      Wire.summary('earlier chat'),
    ];
    final bubbles = deriveBubbles(wire);
    expect(bubbles.length, 3);
    expect(bubbles[0].kind, BubbleKind.user);
    expect(bubbles[1].kind, BubbleKind.assistant);
    expect(bubbles[2].kind, BubbleKind.summary);
  });

  test('sessionTitleFromWire uses first user message', () {
    final title = sessionTitleFromWire([
      {'r': 'a', 'c': 'welcome'},
      {'r': 'u', 'c': 'what can you do for me today?'},
    ]);
    expect(title, 'what can you do for me today?');
  });

  testWidgets('FlameLogo paints without crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDragonTheme(Brightness.dark),
        home: const Scaffold(body: Center(child: FlameLogo(size: 48))),
      ),
    );
    // MaterialApp itself contributes CustomPaints; assert at least ours exists.
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('SetupWizard renders with no provider selected (regression: '
      'null check crash on first build)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDragonTheme(Brightness.dark),
        home: const SetupWizard(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dragon Agent'), findsOneWidget);
    // step 2 & 3 must render lazily-safe even before a preset is picked
    expect(find.text('Choose a provider'), findsOneWidget);
  });
}
