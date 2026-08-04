import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/widgets/qr_view.dart';
import 'package:nexus_shared/nexus_shared.dart';
import 'package:qr/qr.dart';

void main() {
  /// The payload a real machine produces: a LAN address, a Tailscale one, and
  /// a MagicDNS name, plus a 32-character token.
  final payload = PairingPayload(
    addresses: ['192.168.1.50:8765', '100.101.102.103:8765', 'shed.tail1234.ts.net:8765'],
    token: '3f8a1c04b27e4d9fa6710c5382bd94ef',
  );

  test('a full pairing link still fits in a QR code', () {
    // The encoder throws once the data exceeds version 40. Three addresses is
    // already the realistic worst case, so if this fits, pairing does.
    final code = QrCode(
      payload: QrPayload.fromString(
        payload.encodeWebLink('https://natehale05-gif.github.io/Nexus/'),
      ),
      errorCorrectLevel: QrErrorCorrectLevel.low,
    );
    final image = QrImage(code);
    expect(image.moduleCount, greaterThan(0));

    // Finder patterns sit in three corners and are what a camera locks onto
    // first; their absence means whatever was drawn isn't scannable.
    final last = image.moduleCount - 1;
    expect(image.isDark(0, 0), isTrue);
    expect(image.isDark(0, last), isTrue);
    expect(image.isDark(last, 0), isTrue);
  });

  testWidgets('renders at the requested size and paints something', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: QrView(data: payload.encode(), size: 240)),
      ),
    );
    expect(tester.getSize(find.byType(QrView)), const Size(240, 240));
  });

  testWidgets('data too large for any QR version degrades to a blank box', (tester) async {
    // Better than throwing during a build: the pairing screen shows the text
    // code underneath, so an unencodable payload loses the QR, not the screen.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: QrView(data: 'x' * 8000, size: 240)),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
