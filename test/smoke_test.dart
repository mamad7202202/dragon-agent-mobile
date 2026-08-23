import 'package:flutter_test/flutter_test.dart';
import 'package:dragon_agent_mobile/core/theme.dart';
import 'package:dragon_agent_mobile/data/models.dart';
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
    expect(find.byType(CustomPaint), findsOneWidget);
  });
}
