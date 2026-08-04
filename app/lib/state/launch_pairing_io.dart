/// Native: the app isn't launched from a URL, so there's never a pairing in
/// one. Pairing on desktop and mobile goes through the pasted code instead.
library;

import 'package:nexus_shared/nexus_shared.dart';

PairingPayload? pairingFromLaunchUrl() => null;

void clearLaunchPairing() {}
