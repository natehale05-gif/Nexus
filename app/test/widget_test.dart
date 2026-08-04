import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_app/main.dart';
import 'package:nexus_app/screens/nav_menu.dart';

void main() {
  testWidgets('NEXUS app boots to the Home tab with the map visible', (WidgetTester tester) async {
    await tester.pumpWidget(const NexusApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('every section is one tap away from the bottom bar', (WidgetTester tester) async {
    await tester.pumpWidget(const NexusApp());
    await tester.pump(const Duration(milliseconds: 500));

    // The whole point of replacing the pop-up menu: no intermediate step.
    expect(find.byType(NexusTabBar), findsOneWidget);
    for (final spec in nexusTabs) {
      expect(
        find.descendant(of: find.byType(NexusTabBar), matching: find.text(spec.label)),
        findsOneWidget,
        reason: '${spec.label} should be reachable without opening a menu',
      );
    }

    await tester.tap(
      find.descendant(of: find.byType(NexusTabBar), matching: find.text('Settings')),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // "Settings" now appears twice: once as the tab label, once as the title.
    expect(find.text('Settings'), findsNWidgets(2));
  });
}
