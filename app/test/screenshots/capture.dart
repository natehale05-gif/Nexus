/// Renders the app to PNGs so its UI can actually be looked at.
///
/// Deliberately not named `*_test.dart`: `flutter test` must not pick it up,
/// because the goldens are host-specific and it needs a font path that only
/// exists on the machine that captured them. Run it on purpose:
///
///     flutter test test/screenshots/capture.dart --update-goldens
///
/// then open `test/screenshots/goldens/*.png`.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'package:nexus_app/main.dart';
import 'package:nexus_app/screens/nav_menu.dart';
import 'package:nexus_app/theme/tokens.dart';
import 'package:nexus_app/widgets/qr_view.dart';

Future<void> _loadFonts() async {
  // flutter_tester lives at <sdk>/bin/cache/artifacts/engine/<host>/, so the
  // bundled fonts are two directories up from its own artifacts folder.
  final engineDir = File(Platform.resolvedExecutable).parent;
  final dir = '${engineDir.parent.parent.path}/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(File('$dir/$f').readAsBytes().then((b) => b.buffer.asByteData()));
    }
    await loader.load();
  }

  // The app names no primary family (it relies on a fallback list), and the
  // test engine's default font draws every glyph as a box - so register the
  // real faces under every name the app might resolve to.
  for (final family in ['.SF Pro Text', 'SF Pro Text', 'Roboto', 'FlutterTest', 'Ahem']) {
    await load(family, ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  }
}

/// The app touches secure storage, path_provider and media_kit at startup;
/// none have a binding under `flutter test`.
void _stubPlugins() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in const [
    'plugins.it_nomads.com/flutter_secure_storage',
    'plugins.flutter.io/path_provider',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') return '/tmp/nexus-shots';
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadFonts();
    _stubPlugins();
  });

  /// The way past onboarding into something with content in it.
  final demoLink = find.text('Just looking? Open the example compound');

  Future<void> shot(WidgetTester tester, NexusTab tab, String name, Size size) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const NexusApp());
    await tester.pump(const Duration(milliseconds: 600));

    // First run lands on onboarding; take the demo so there's content.
    if (demoLink.evaluate().isNotEmpty) {
      await tester.tap(demoLink);
      await tester.pump(const Duration(milliseconds: 600));
    }

    if (tab != NexusTab.home) {
      // Wide windows use the rail instead of the bar.
      final nav = find.byType(NexusTabBar).evaluate().isNotEmpty
          ? find.byType(NexusTabBar)
          : find.byType(NexusSidebar);
      await tester.tap(find.descendant(of: nav, matching: find.text(specFor(tab).label)));
      // Implicit animations need a second frame past their end to settle, and
      // pumpAndSettle never returns here (the heartbeat pulses forever).
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }
    await expectLater(find.byType(NexusApp), matchesGoldenFile('goldens/$name.png'));
  }

  const phone = Size(390, 844);


  // Onboarding is deliberately not captured: it is the one screen with no
  // interaction, and static text laid out on a test's first frame keeps the
  // engine's box-glyph font no matter how many frames are pumped after it.
  testWidgets('home', (t) => shot(t, NexusTab.home, 'home', phone));
  testWidgets('drive', (t) => shot(t, NexusTab.drive, 'drive', phone));
  testWidgets('security', (t) => shot(t, NexusTab.security, 'security', phone));
  testWidgets('tv', (t) => shot(t, NexusTab.tv, 'tv', phone));
  testWidgets('ai', (t) => shot(t, NexusTab.nexusAi, 'ai', phone));
  testWidgets('settings', (t) => shot(t, NexusTab.settings, 'settings', phone));
  testWidgets('wide', (t) => shot(t, NexusTab.settings, 'wide', const Size(1200, 820)));

  // The QR itself, against a payload shaped like a real machine's. Worth its
  // own capture: a QR that encodes but paints blank looks fine in code and is
  // useless in the one moment it matters.
  testWidgets('qr', (tester) async {
    final payload = PairingPayload(
      addresses: ['192.168.1.50:8765', '100.101.102.103:8765', 'shed.tail1234.ts.net:8765'],
      token: '3f8a1c04b27e4d9fa6710c5382bd94ef',
    );
    await tester.binding.setSurfaceSize(const Size(280, 280));
    tester.view.physicalSize = const Size(280, 280);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      Container(
        alignment: Alignment.center,
        color: NexusColors.background,
        child: QrView(data: payload.encodeWebLink('https://natehale05-gif.github.io/Nexus/')),
      ),
    );
    await tester.pump();
    await expectLater(find.byType(QrView), matchesGoldenFile('goldens/qr.png'));
  });

  // The pairing invite, rendered against a payload that looks like a real
  // machine's - a LAN address plus a Tailscale one.
  testWidgets('pairing', (tester) async {
    await tester.binding.setSurfaceSize(phone);
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(const NexusApp());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(demoLink);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(
      find.descendant(of: find.byType(NexusTabBar), matching: find.text('Settings')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Server'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(NexusApp), matchesGoldenFile('goldens/pairing.png'));
  });

  // Local AI on a machine with no engine installed - the state a new user
  // actually sees.
  testWidgets('local-ai', (tester) async {
    await shot(tester, NexusTab.settings, 'settings', phone);
    await tester.tap(find.text('AI'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(NexusApp), matchesGoldenFile('goldens/local_ai.png'));
  });

  // The setup flow that matters most: Settings > Server.
  testWidgets('settings-server', (tester) async {
    await shot(tester, NexusTab.settings, 'settings', phone);
    await tester.tap(find.text('Server'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(NexusApp),
      matchesGoldenFile('goldens/settings_server.png'),
    );
  });
}
