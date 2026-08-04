/// Where the browser build of NEXUS lives.
///
/// The QR code a server shows encodes a link to this, with the pairing in the
/// fragment - so scanning it with a phone's camera opens a working, paired
/// NEXUS without installing anything first. Overridable at build time for a
/// fork or a self-hosted copy:
///
///     flutter build windows --dart-define=NEXUS_WEB_APP_URL=https://nexus.example.com/
library;

const nexusWebAppUrl = String.fromEnvironment(
  'NEXUS_WEB_APP_URL',
  defaultValue: 'https://natehale05-gif.github.io/Nexus/',
);
