import AppIntents
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

// MARK: - Siri
//
// The same App Intents as iOS. Kept in AppDelegate.swift for the same reason:
// a new Swift file has to be added to the Xcode target by hand, and one that
// silently isn't a member compiles fine and ships doing nothing. This file is
// unambiguously in the build.
//
// They call the compound server's REST API directly rather than going through
// Flutter, because a spoken command has to work with NEXUS closed.

/// Where the compound server is, as Dart resolved it.
struct NexusPairing {
  let bases: [String]
  let token: String

  /// Keychain rather than UserDefaults: the token grants full control of the
  /// compound and sits on the machine indefinitely.
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

/// Runs one action against the compound, trying each known address in turn -
/// the same failover the app itself does, so a spoken command works at home
/// and away without anyone reconfiguring anything.
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
        continue
      }
    }
    return Reply(ok: false, spoken: "NEXUS couldn't reach your compound server.")
  }
}

@available(macOS 13.0, *)
struct NexusControlIntent: AppIntent {
  static var title: LocalizedStringResource = "Control the compound"
  static var description = IntentDescription(
    "Turn something on or off, lock a gate, or set a thermostat."
  )
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
    let reply = await NexusClient.run(action: action.rawValue, phrase: name, value: value)
    return .result(dialog: IntentDialog(stringLiteral: reply.spoken))
  }
}

@available(macOS 13.0, *)
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

@available(macOS 13.0, *)
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
/// Mirrors the server's allow-list, including by omission: there is no case
/// here that reaches NEXUS's own assistant.
@available(macOS 13.0, *)
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

@available(macOS 13.0, *)
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
