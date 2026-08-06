import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Dart hands the pairing over whenever it changes, so the App Intents in
    // AppDelegate.swift can reach the compound server without the app being
    // open. See NexusPairingChannel there.
    NexusPairingChannel.register(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
