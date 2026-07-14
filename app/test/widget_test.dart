import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_app/main.dart';

void main() {
  testWidgets('NEXUS app boots to the Home tab with the map visible', (WidgetTester tester) async {
    await tester.pumpWidget(const NexusApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CustomPaint), findsWidgets);
  });
}
