import AppIntents
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Dart hands the pairing over whenever it changes, so the App Intents
    // below can reach the compound server on their own.
    if let controller = window?.rootViewController as? FlutterViewController {
      NexusPairingChannel.register(messenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - Siri
//
// These live in AppDelegate.swift rather than their own file on purpose. A
// new file has to be added to the Xcode target by hand, and iOS isn't built
// by CI here - a file that silently isn't a member of the target compiles
// fine locally and ships doing nothing. This one is unambiguously in the
// build. Split it out when someone has Xcode open.
//
// They talk to the compound server's REST API directly rather than going
// through Flutter. Siri has to work with NEXUS closed, and a spoken command
// that first waits for an app and its engine to launch is a spoken command
// that feels broken.

/// Where the compound server is, as Dart resolved it.
///
/// Dart already knows which addresses the server answers on and how to build
/// its REST base URL; recomputing that in Swift would be a second
/// implementation to keep in step. So it just hands over the finished list.
struct NexusPairing {
  let bases: [String]
  let token: String

  /// Keychain, not UserDefaults: the token grants full control of the
  /// compound, and this is a value that sits on the device indefinitely.
  private static let service = "com.nexus.compound.pairing"
  private static let account = "server"

  static func load() -> NexusPairing? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let token = json["token"] as? String,
          let bases = json["bases"] as? [String],
          !bases.isEmpty
    else { return nil }
    return NexusPairing(bases: bases, token: token)
  }

  static func save(bases: [String], token: String) {
    let payload: [String: Any] = ["bases": bases, "token": token]
    guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
    var insert = query
    insert[kSecValueData as String] = data
    // Available after first unlock so a shortcut can run from the lock screen
    // or a HomePod, but never synced to another device.
    insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(insert as CFDictionary, nil)
  }

  static func clear() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }
}

/// Lets Dart keep the Keychain copy of the pairing current.
enum NexusPairingChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "nexus/pairing", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "save":
        let args = call.arguments as? [String: Any] ?? [:]
        NexusPairing.save(
          bases: args["bases"] as? [String] ?? [],
          token: args["token"] as? String ?? ""
        )
        result(true)
      case "clear":
        NexusPairing.clear()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Runs one action against the compound.
///
/// Tries each address in turn, which is the same failover the app does: the
/// LAN address is right at home and useless anywhere else, and a spoken
/// command should work in both places without anyone reconfiguring anything.
enum NexusClient {
  struct Reply {
    let ok: Bool
    let spoken: String
  }

  static func run(action: String, phrase: String = "", value: Double? = nil) async -> Reply {
    guard let pairing = NexusPairing.load() else {
      return Reply(ok: false, spoken: "NEXUS isn't set up on this device yet.")
    }

    var body: [String: Any] = ["action": action, "phrase": phrase]
    if let value { body["value"] = value }
    guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
      return Reply(ok: false, spoken: "NEXUS couldn't build that request.")
    }

    for base in pairing.bases {
      guard let url = URL(string: "\(base)/intents/run") else { continue }
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.httpBody = payload
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer \(pairing.token)", forHTTPHeaderField: "Authorization")
      // Short: a voice request that hangs for thirty seconds has already
      // failed, and there may be another address that works.
      request.timeoutInterval = 6

      do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { continue }
        return Reply(
          ok: json["ok"] as? Bool ?? false,
          spoken: json["spoken"] as? String ?? "Done."
        )
      } catch {
        continue // Wrong network for this address; try the next one.
      }
    }
    return Reply(ok: false, spoken: "NEXUS couldn't reach your compound server.")
  }
}

@available(iOS 16.0, *)
struct NexusControlIntent: AppIntent {
  static var title: LocalizedStringResource = "Control the compound"
  static var description = IntentDescription(
    "Turn something on or off, lock a gate, or set a thermostat."
  )
  // No UI needed: the whole point is that this works without opening NEXUS.
  static var openAppWhenRun: Bool = false

  @Parameter(title: "What to do")
  var action: NexusActionAppEnum

  @Parameter(title: "Which one")
  var name: String

  @Parameter(title: "Value", description: "Brightness percent, or degrees.")
  var value: Double?

  static var parameterSummary: some ParameterSummary {
    Summary("\(\.$action) \(\.$name)")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let reply = await NexusClient.run(
      action: action.rawValue,
      phrase: name,
      value: value
    )
    return .result(dialog: IntentDialog(stringLiteral: reply.spoken))
  }
}

@available(iOS 16.0, *)
struct NexusStatusIntent: AppIntent {
  static var title: LocalizedStringResource = "Check the compound"
  static var description = IntentDescription("Ask how the compound, or one thing on it, is doing.")
  static var openAppWhenRun: Bool = false

  @Parameter(title: "Which one", description: "Leave empty for the whole compound.")
  var name: String?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let spoken = (name ?? "").isEmpty
      ? await NexusClient.run(action: "compoundStatus").spoken
      : await NexusClient.run(action: "status", phrase: name ?? "").spoken
    return .result(dialog: IntentDialog(stringLiteral: spoken))
  }
}

@available(iOS 16.0, *)
struct NexusAllLightsOffIntent: AppIntent {
  static var title: LocalizedStringResource = "Turn every light off"
  static var openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let reply = await NexusClient.run(action: "allLightsOff")
    return .result(dialog: IntentDialog(stringLiteral: reply.spoken))
  }
}

/// The verbs Siri can use.
///
/// This mirrors the server's allow-list, and mirrors it *by omission* too:
/// there is no case here that reaches NEXUS's own assistant. Two assistants
/// relaying to each other is a game of telephone where neither is
/// accountable for the answer.
@available(iOS 16.0, *)
enum NexusActionAppEnum: String, AppEnum {
  case turnOn
  case turnOff
  case lock
  case unlock
  case setBrightness
  case setTemperature

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
  static var caseDisplayRepresentations: [NexusActionAppEnum: DisplayRepresentation] = [
    .turnOn: "Turn on",
    .turnOff: "Turn off",
    .lock: "Lock or close",
    .unlock: "Unlock or open",
    .setBrightness: "Set brightness",
    .setTemperature: "Set temperature",
  ]
}

@available(iOS 16.0, *)
struct NexusShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: NexusAllLightsOffIntent(),
      phrases: [
        "Turn off all the lights in \(.applicationName)",
        "\(.applicationName) lights out",
      ],
      shortTitle: "Lights out",
      systemImageName: "lightbulb.slash"
    )
    AppShortcut(
      intent: NexusStatusIntent(),
      phrases: [
        "How is the compound in \(.applicationName)",
        "Check the compound in \(.applicationName)",
      ],
      shortTitle: "Compound status",
      systemImageName: "house"
    )
  }
}
