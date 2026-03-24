# Hubitat Platform Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Hubitat Elevation as a third smart home platform, using the Maker API (REST) for device control and the EventSocket (WebSocket) for real-time state updates, following the established Home Assistant integration pattern exactly.

**Architecture:** The Hubitat integration mirrors the Home Assistant pattern: a REST+WebSocket client (`HubitatClient`), a capability-to-ServiceData mapper (`HubitatDeviceMapper`), a `SmartHomePlatform` conformance (`HubitatPlatform`), and a `Mac2iOS` bridge adapter (`HubitatBridge`). The platform is registered in `PlatformManager` and `SmartHomePlatformType` as a third option alongside HomeKit and Home Assistant. Onboarding and settings UI follow the same card-based pattern.

**Tech Stack:** Swift 5.9, AppKit (macOS plugin), URLSession (REST + WebSocket), Keychain (credential storage), XcodeGen (project.yml)

---

## Design Decisions

### API Strategy: Maker API + EventSocket

The Maker API provides REST endpoints for device listing, status, and command execution. For real-time updates, we use the **EventSocket** (`ws://hub_ip/eventsocket`) rather than Maker API webhooks because:

1. **No server needed** - webhooks require the app to run an HTTP server (sandbox complications on macOS)
2. **Immediate** - WebSocket events arrive instantly, no polling
3. **Already proven** - the HA integration uses WebSocket for the same purpose
4. **LAN-only is fine** - this is a macOS menu bar app running on the same network as the hub

The EventSocket delivers ALL hub events (not filtered to Maker API devices), so we filter client-side to only process events for devices authorized in the Maker API.

### Capability Mapping

Hubitat uses a capability model (Switch, SwitchLevel, ColorControl, etc.) rather than HA's domain model (light, switch, climate). The mapper inspects each device's `capabilities` array to determine the appropriate Itsyhome service type:

| Hubitat Capability | Itsyhome ServiceType | Notes |
|---|---|---|
| Switch | switch (or outlet) | outlet if device type contains "outlet" or "plug" |
| SwitchLevel | lightbulb | with brightness support |
| ColorControl | lightbulb | with hue/saturation; combined with SwitchLevel |
| ColorTemperature | lightbulb | with color temp; Hubitat uses Kelvin natively |
| Lock | lock | locked/unlocked enum |
| Thermostat | thermostat | full HVAC support |
| WindowShade | windowCovering | position-based |
| GarageDoorControl | garageDoor | open/closed/opening/closing |
| Valve | valve | open/closed |
| Fan | fanV2 | with speed if FanControl capability present |
| TemperatureMeasurement | temperatureSensor | read-only |
| RelativeHumidityMeasurement | humiditySensor | read-only |
| MotionSensor | (binary sensor) | motion active/inactive |
| ContactSensor | (binary sensor) | contact open/closed |

### What's NOT Supported (Initially)

- **Cameras** - Hubitat has no camera API via Maker API. `hasCameras` returns `false`.
- **Scenes** - Maker API doesn't expose scenes/rules. Could be added later via direct hub API.
- **HSM (Hubitat Safety Monitor)** - Available via Maker API (`/hsm`). Mapped to securitySystem/alarm. Included in scope.
- **Modes** - Available via `/modes`. Not mapped to scenes (they're different concepts). Could be exposed as a future enhancement.
- **Cloud access** - LAN-only initially. Cloud support could be added later with a different base URL.

### Credential Storage

Following the HA pattern exactly:
- **Hub URL** - `UserDefaults` (key: `HubitatHubURL`)
- **App ID** - `UserDefaults` (key: `HubitatAppId`)
- **Access Token** - Keychain (service: `com.nickustinov.itsyhome.hubitat`)

### UUID Generation

Same deterministic UUID strategy as HA: `deterministicUUID(for: "hubitat_device_42")` for devices, `deterministicUUID(for: "hubitat_device_42.power")` for characteristics. This ensures stable UUIDs across sessions.

---

## File Structure

### New Files to Create

```
Itsyhome/Hubitat/
├── HubitatClient.swift           # REST (Maker API) + WebSocket (EventSocket) client
├── HubitatModels.swift           # Hubitat API response models
├── HubitatDeviceMapper.swift     # Capability → ServiceData mapping
├── HubitatAuthManager.swift      # Credential management (hub URL, app ID, token)
├── HubitatPlatform.swift         # SmartHomePlatform conformance
├── HubitatPlatform+Actions.swift # writeCharacteristic / executeScene
└── HubitatPlatform+Delegate.swift # HubitatClientDelegate handling

macOSBridge/Hubitat/
└── HubitatBridge.swift           # Mac2iOS adapter (same pattern as HomeAssistantBridge)

macOSBridge/PlatformPicker/
└── HubitatConnectWindowController.swift  # Onboarding: hub URL + app ID + token entry

macOSBridge/Settings/Sections/
└── HubitatSection.swift          # Settings panel for Hubitat connection

macOSBridge/Resources/
└── hubitat.png                   # Hubitat logo icon (for platform picker & settings)

macOSBridgeTests/Hubitat/
├── HubitatModelsTests.swift
├── HubitatDeviceMapperTests.swift
├── HubitatClientTests.swift
└── HubitatPlatformTests.swift
```

### Existing Files to Modify

```
Itsyhome/Shared/SmartHomePlatform.swift     # Add .hubitat to SmartHomePlatformType
Itsyhome/Shared/PlatformManager.swift       # Add .hubitat to SelectedPlatform + selection method
macOSBridge/MacOSController.swift           # Wire up HubitatPlatform + HubitatBridge
macOSBridge/Settings/SettingsView.swift      # Add .hubitat settings section
macOSBridge/Settings/Sections/GeneralSection.swift  # Add Hubitat card to platform picker
macOSBridge/PlatformPicker/PlatformPickerWindowController.swift  # Add Hubitat card to onboarding
project.yml                                 # Add Itsyhome/Hubitat source path
```

---

## Tasks

### Task 1: Platform Registration (Enums & PlatformManager)

**Files:**
- Modify: `Itsyhome/Shared/SmartHomePlatform.swift:12-15` (SmartHomePlatformType enum)
- Modify: `Itsyhome/Shared/SmartHomePlatform.swift:92-103` (PlatformCapabilities)
- Modify: `Itsyhome/Shared/PlatformManager.swift:15-19` (SelectedPlatform enum)
- Modify: `Itsyhome/Shared/PlatformManager.swift:68-78` (isPlatformConfigured)
- Modify: `Itsyhome/Shared/PlatformManager.swift:120-134` (selection methods)

- [ ] **Step 1: Add `.hubitat` to `SmartHomePlatformType`**

In `SmartHomePlatform.swift`, add the new case:

```swift
public enum SmartHomePlatformType: String, Codable {
    case homeKit = "homekit"
    case homeAssistant = "homeassistant"
    case hubitat = "hubitat"
}
```

- [ ] **Step 2: Add `PlatformCapabilities.hubitat`**

```swift
public static let hubitat = PlatformCapabilities(
    supportsMultipleHomes: false,
    supportsSceneStateTracking: false,
    supportsOutletInUse: false
)
```

- [ ] **Step 3: Add `.hubitat` to `SelectedPlatform`**

In `PlatformManager.swift`:

```swift
public enum SelectedPlatform: String, Codable {
    case none = "none"
    case homeKit = "homekit"
    case homeAssistant = "homeassistant"
    case hubitat = "hubitat"
}
```

- [ ] **Step 4: Add `isPlatformConfigured` case for Hubitat**

```swift
case .hubitat:
    return UserDefaults.standard.string(forKey: "HubitatHubURL") != nil
```

- [ ] **Step 5: Add `selectHubitat()` method**

```swift
public func selectHubitat() {
    selectedPlatform = .hubitat
    hasCompletedOnboarding = true
    logger.info("Hubitat selected")
    NotificationCenter.default.post(name: .platformDidChange, object: nil)
}
```

- [ ] **Step 6: Update `clearHomeAssistantCredentials` comment or add Hubitat equivalent**

Add:
```swift
public func clearHubitatCredentials() {
    UserDefaults.standard.removeObject(forKey: "HubitatHubURL")
    UserDefaults.standard.removeObject(forKey: "HubitatAppId")
    // Token is in Keychain, cleared by HubitatAuthManager
}
```

- [ ] **Step 7: Commit**

```bash
git add Itsyhome/Shared/SmartHomePlatform.swift Itsyhome/Shared/PlatformManager.swift
git commit -m "feat(hubitat): register Hubitat platform type in enums and PlatformManager"
```

---

### Task 2: Credential Management (HubitatAuthManager)

**Files:**
- Create: `Itsyhome/Hubitat/HubitatAuthManager.swift`
- Test: `macOSBridgeTests/Hubitat/HubitatAuthManagerTests.swift`

- [ ] **Step 1: Write tests for HubitatAuthManager**

```swift
import XCTest
@testable import macOSBridge

final class HubitatAuthManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Clear any existing test data
        UserDefaults.standard.removeObject(forKey: "HubitatHubURL")
        UserDefaults.standard.removeObject(forKey: "HubitatAppId")
        HubitatAuthManager.shared.accessToken = nil
    }

    func testIsConfiguredReturnsFalseWhenNoCredentials() {
        XCTAssertFalse(HubitatAuthManager.shared.isConfigured)
    }

    func testSaveAndRetrieveCredentials() {
        let url = URL(string: "http://192.168.1.100")!
        HubitatAuthManager.shared.saveCredentials(hubURL: url, appId: "42", accessToken: "test-token")
        XCTAssertEqual(HubitatAuthManager.shared.hubURL, url)
        XCTAssertEqual(HubitatAuthManager.shared.appId, "42")
        XCTAssertEqual(HubitatAuthManager.shared.accessToken, "test-token")
        XCTAssertTrue(HubitatAuthManager.shared.isConfigured)
    }

    func testClearCredentials() {
        let url = URL(string: "http://192.168.1.100")!
        HubitatAuthManager.shared.saveCredentials(hubURL: url, appId: "42", accessToken: "test-token")
        HubitatAuthManager.shared.clearCredentials()
        XCTAssertNil(HubitatAuthManager.shared.hubURL)
        XCTAssertNil(HubitatAuthManager.shared.appId)
        XCTAssertNil(HubitatAuthManager.shared.accessToken)
        XCTAssertFalse(HubitatAuthManager.shared.isConfigured)
    }

    func testMakerAPIBaseURL() {
        let url = URL(string: "http://192.168.1.100")!
        HubitatAuthManager.shared.saveCredentials(hubURL: url, appId: "42", accessToken: "test-token")
        let baseURL = HubitatAuthManager.shared.makerAPIBaseURL
        XCTAssertEqual(baseURL?.absoluteString, "http://192.168.1.100/apps/api/42")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Itsyhome.xcodeproj -scheme Itsyhome -destination 'platform=macOS' -only-testing:macOSBridgeTests/HubitatAuthManagerTests 2>&1 | tail -20`
Expected: compilation error (HubitatAuthManager not defined)

- [ ] **Step 3: Implement HubitatAuthManager**

Create `Itsyhome/Hubitat/HubitatAuthManager.swift`:

```swift
//
//  HubitatAuthManager.swift
//  Itsyhome
//
//  Hubitat Maker API credential management
//

import Foundation
import Security
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatAuthManager")

final class HubitatAuthManager {

    // MARK: - Singleton

    static let shared = HubitatAuthManager()

    // MARK: - Constants

    private let hubURLKey = "HubitatHubURL"
    private let appIdKey = "HubitatAppId"
    private let keychainService = "com.nickustinov.itsyhome.hubitat"
    private let keychainAccount = "access_token"

    // MARK: - Properties

    /// The Hubitat hub URL (e.g., http://192.168.1.100)
    var hubURL: URL? {
        get {
            guard let urlString = UserDefaults.standard.string(forKey: hubURLKey) else { return nil }
            return URL(string: urlString)
        }
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.absoluteString, forKey: hubURLKey)
            } else {
                UserDefaults.standard.removeObject(forKey: hubURLKey)
            }
        }
    }

    /// The Maker API app ID
    var appId: String? {
        get { UserDefaults.standard.string(forKey: appIdKey) }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: appIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: appIdKey)
            }
        }
    }

    /// The access token (stored securely in Keychain)
    var accessToken: String? {
        get { readTokenFromKeychain() }
        set {
            if let token = newValue {
                saveTokenToKeychain(token)
            } else {
                deleteTokenFromKeychain()
            }
        }
    }

    /// Whether all credentials are configured
    var isConfigured: Bool {
        hubURL != nil && appId != nil && accessToken != nil
    }

    /// Base URL for Maker API requests: http://hub_ip/apps/api/{appId}
    var makerAPIBaseURL: URL? {
        guard let hubURL = hubURL, let appId = appId else { return nil }
        return hubURL.appendingPathComponent("apps/api/\(appId)")
    }

    /// EventSocket URL: ws://hub_ip/eventsocket
    var eventSocketURL: URL? {
        guard let hubURL = hubURL else { return nil }
        var components = URLComponents(url: hubURL, resolvingAgainstBaseURL: false)
        components?.scheme = "ws"
        components?.path = "/eventsocket"
        return components?.url
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public methods

    func saveCredentials(hubURL: URL, appId: String, accessToken: String) {
        self.hubURL = hubURL
        self.appId = appId
        self.accessToken = accessToken
        logger.info("Credentials saved for \(hubURL.host ?? "unknown", privacy: .public)")
    }

    func clearCredentials() {
        hubURL = nil
        appId = nil
        accessToken = nil
        logger.info("Credentials cleared")
    }

    /// Validate credentials by fetching the device list
    func validateCredentials() async throws -> Bool {
        guard let baseURL = makerAPIBaseURL, let token = accessToken else {
            throw HubitatAuthError.notConfigured
        }

        let url = baseURL.appendingPathComponent("devices")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "access_token", value: token)]

        let (_, response) = try await URLSession.shared.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw HubitatAuthError.invalidCredentials
        }
        return true
    }

    /// Validate and fetch device count for onboarding
    func validateAndFetchDeviceCount() async throws -> Int {
        guard let baseURL = makerAPIBaseURL, let token = accessToken else {
            throw HubitatAuthError.notConfigured
        }

        let url = baseURL.appendingPathComponent("devices")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "access_token", value: token)]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw HubitatAuthError.invalidCredentials
        }

        guard let devices = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw HubitatAuthError.invalidResponse
        }
        return devices.count
    }

    // MARK: - Keychain operations

    private func saveTokenToKeychain(_ token: String) {
        guard let tokenData = token.data(using: .utf8) else { return }
        deleteTokenFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func readTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            return token
        }
        return nil
    }

    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum HubitatAuthError: LocalizedError {
    case notConfigured
    case invalidCredentials
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Hubitat is not configured"
        case .invalidCredentials: return "Invalid hub URL, app ID, or access token"
        case .invalidResponse: return "Invalid response from Hubitat hub"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add Itsyhome/Hubitat/HubitatAuthManager.swift macOSBridgeTests/Hubitat/HubitatAuthManagerTests.swift
git commit -m "feat(hubitat): add HubitatAuthManager for credential storage"
```

---

### Task 3: Hubitat Data Models (HubitatModels)

**Files:**
- Create: `Itsyhome/Hubitat/HubitatModels.swift`
- Test: `macOSBridgeTests/Hubitat/HubitatModelsTests.swift`

- [ ] **Step 1: Write tests for model parsing**

```swift
import XCTest
@testable import macOSBridge

final class HubitatModelsTests: XCTestCase {

    func testParseDeviceSummary() {
        let json: [String: Any] = ["id": "1", "name": "Virtual Switch", "label": "Living Room Light"]
        let device = HubitatDeviceSummary(json: json)
        XCTAssertNotNil(device)
        XCTAssertEqual(device?.id, "1")
        XCTAssertEqual(device?.name, "Virtual Switch")
        XCTAssertEqual(device?.label, "Living Room Light")
    }

    func testParseDeviceDetail() {
        let json: [String: Any] = [
            "id": "1",
            "name": "Virtual Dimmer",
            "label": "Kitchen Light",
            "type": "Virtual Dimmer",
            "capabilities": ["Switch", "SwitchLevel", "Refresh"],
            "attributes": ["switch": "on", "level": 75],
            "commands": [
                ["command": "on"],
                ["command": "off"],
                ["command": "setLevel", "type": ["NUMBER"]]
            ]
        ]
        let device = HubitatDevice(json: json)
        XCTAssertNotNil(device)
        XCTAssertEqual(device?.id, "1")
        XCTAssertEqual(device?.label, "Kitchen Light")
        XCTAssertTrue(device?.capabilities.contains("Switch") ?? false)
        XCTAssertTrue(device?.capabilities.contains("SwitchLevel") ?? false)
        XCTAssertEqual(device?.attributes["switch"] as? String, "on")
        XCTAssertEqual(device?.attributes["level"] as? Int, 75)
        XCTAssertEqual(device?.commands.count, 3)
    }

    func testParseDeviceCommand() {
        let json: [String: Any] = ["command": "setLevel", "type": ["NUMBER", "NUMBER"]]
        let command = HubitatCommand(json: json)
        XCTAssertNotNil(command)
        XCTAssertEqual(command?.command, "setLevel")
        XCTAssertEqual(command?.parameterTypes, ["NUMBER", "NUMBER"])
    }

    func testParseEventSocketMessage() {
        let json: [String: Any] = [
            "source": "DEVICE",
            "name": "switch",
            "displayName": "Living Room Light",
            "value": "off",
            "deviceId": "1",
            "descriptionText": "Living Room Light was turned off"
        ]
        let event = HubitatEvent(json: json)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.source, "DEVICE")
        XCTAssertEqual(event?.name, "switch")
        XCTAssertEqual(event?.value, "off")
        XCTAssertEqual(event?.deviceId, "1")
        XCTAssertEqual(event?.displayName, "Living Room Light")
    }

    func testParseHSMStatus() {
        let json: [String: Any] = ["hsm": "armedAway"]
        let status = HubitatHSMStatus(json: json)
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.status, "armedAway")
    }

    func testParseMode() {
        let json: [String: Any] = ["id": 1, "name": "Home", "active": true]
        let mode = HubitatMode(json: json)
        XCTAssertNotNil(mode)
        XCTAssertEqual(mode?.id, "1")
        XCTAssertEqual(mode?.name, "Home")
        XCTAssertTrue(mode?.active ?? false)
    }

    func testDeviceDisplayName() {
        // label takes priority over name
        let json: [String: Any] = [
            "id": "1", "name": "Generic Z-Wave Switch", "label": "Kitchen Switch",
            "type": "Generic Z-Wave Switch",
            "capabilities": ["Switch"], "attributes": [:], "commands": []
        ]
        let device = HubitatDevice(json: json)
        XCTAssertEqual(device?.displayName, "Kitchen Switch")

        // Falls back to name if no label
        let json2: [String: Any] = [
            "id": "2", "name": "Virtual Switch", "label": "",
            "type": "Virtual Switch",
            "capabilities": ["Switch"], "attributes": [:], "commands": []
        ]
        let device2 = HubitatDevice(json: json2)
        XCTAssertEqual(device2?.displayName, "Virtual Switch")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement HubitatModels**

Create `Itsyhome/Hubitat/HubitatModels.swift`:

```swift
//
//  HubitatModels.swift
//  Itsyhome
//
//  Hubitat Maker API data models
//

import Foundation

// MARK: - Device summary (from /devices endpoint)

struct HubitatDeviceSummary {
    let id: String
    let name: String
    let label: String?

    init?(json: [String: Any]) {
        // id can come as String or Int from the API
        if let idString = json["id"] as? String {
            self.id = idString
        } else if let idInt = json["id"] as? Int {
            self.id = String(idInt)
        } else {
            return nil
        }
        guard let name = json["name"] as? String else { return nil }
        self.name = name
        self.label = json["label"] as? String
    }
}

// MARK: - Full device detail (from /devices/all or /devices/{id})

struct HubitatDevice {
    let id: String
    let name: String
    let label: String?
    let type: String?
    let manufacturer: String?
    let model: String?
    let capabilities: [String]
    let attributes: [String: Any]
    let commands: [HubitatCommand]

    /// Display name: prefer label, fall back to name
    var displayName: String {
        let labelValue = label ?? ""
        return labelValue.isEmpty ? name : labelValue
    }

    /// Check if device has a specific capability
    func hasCapability(_ capability: String) -> Bool {
        capabilities.contains(capability)
    }

    /// Get attribute value as String
    func attributeString(_ name: String) -> String? {
        if let value = attributes[name] {
            if let s = value as? String { return s }
            if let n = value as? NSNumber { return n.stringValue }
            return nil
        }
        return nil
    }

    /// Get attribute value as Double
    func attributeDouble(_ name: String) -> Double? {
        if let value = attributes[name] {
            if let d = value as? Double { return d }
            if let i = value as? Int { return Double(i) }
            if let s = value as? String { return Double(s) }
            return nil
        }
        return nil
    }

    /// Get attribute value as Int
    func attributeInt(_ name: String) -> Int? {
        if let value = attributes[name] {
            if let i = value as? Int { return i }
            if let d = value as? Double { return Int(d) }
            if let s = value as? String { return Int(s) }
            return nil
        }
        return nil
    }

    init?(json: [String: Any]) {
        if let idString = json["id"] as? String {
            self.id = idString
        } else if let idInt = json["id"] as? Int {
            self.id = String(idInt)
        } else {
            return nil
        }
        guard let name = json["name"] as? String else { return nil }
        self.name = name
        self.label = json["label"] as? String
        self.type = json["type"] as? String
        self.manufacturer = json["manufacturer"] as? String
        self.model = json["model"] as? String

        // Capabilities can be strings or objects with "name" key
        if let caps = json["capabilities"] as? [Any] {
            self.capabilities = caps.compactMap { cap in
                if let s = cap as? String { return s }
                if let d = cap as? [String: Any] { return d["name"] as? String }
                return nil
            }
        } else {
            self.capabilities = []
        }

        self.attributes = json["attributes"] as? [String: Any] ?? [:]

        if let cmds = json["commands"] as? [[String: Any]] {
            self.commands = cmds.compactMap { HubitatCommand(json: $0) }
        } else {
            self.commands = []
        }
    }
}

// MARK: - Device command

struct HubitatCommand {
    let command: String
    let parameterTypes: [String]?

    init?(json: [String: Any]) {
        guard let command = json["command"] as? String else { return nil }
        self.command = command
        self.parameterTypes = json["type"] as? [String]
    }
}

// MARK: - EventSocket event

struct HubitatEvent {
    let source: String       // "DEVICE", "LOCATION", "HUB"
    let name: String         // attribute name: "switch", "level", "motion", etc.
    let displayName: String? // friendly device name
    let value: String        // attribute value: "on", "off", "75", etc.
    let deviceId: String?    // device ID (nil for non-device events)
    let descriptionText: String?
    let unit: String?
    let type: String?        // "digital", "physical", null
    let data: String?

    /// Whether this is a device event (vs location/hub event)
    var isDeviceEvent: Bool {
        source == "DEVICE" && deviceId != nil
    }

    init?(json: [String: Any]) {
        guard let name = json["name"] as? String else { return nil }

        self.source = json["source"] as? String ?? "DEVICE"
        self.name = name
        self.displayName = json["displayName"] as? String

        // Value can be String, Number, or null
        if let v = json["value"] as? String {
            self.value = v
        } else if let v = json["value"] as? NSNumber {
            self.value = v.stringValue
        } else {
            self.value = ""
        }

        // deviceId can be String or Int
        if let d = json["deviceId"] as? String {
            self.deviceId = d
        } else if let d = json["deviceId"] as? Int {
            self.deviceId = String(d)
        } else {
            self.deviceId = nil
        }

        self.descriptionText = json["descriptionText"] as? String
        self.unit = json["unit"] as? String
        self.type = json["type"] as? String
        self.data = json["data"] as? String
    }
}

// MARK: - HSM status

struct HubitatHSMStatus {
    let status: String  // "disarmed", "armedAway", "armedHome", "armedNight"

    init?(json: [String: Any]) {
        guard let status = json["hsm"] as? String else { return nil }
        self.status = status
    }
}

// MARK: - Hub mode

struct HubitatMode {
    let id: String
    let name: String
    let active: Bool

    init?(json: [String: Any]) {
        if let idInt = json["id"] as? Int {
            self.id = String(idInt)
        } else if let idString = json["id"] as? String {
            self.id = idString
        } else {
            return nil
        }
        guard let name = json["name"] as? String else { return nil }
        self.name = name
        self.active = json["active"] as? Bool ?? false
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add Itsyhome/Hubitat/HubitatModels.swift macOSBridgeTests/Hubitat/HubitatModelsTests.swift
git commit -m "feat(hubitat): add Hubitat API data models"
```

---

### Task 4: API Client (HubitatClient)

**Files:**
- Create: `Itsyhome/Hubitat/HubitatClient.swift`
- Test: `macOSBridgeTests/Hubitat/HubitatClientTests.swift`

This is the largest single file. It combines:
- REST client for Maker API (device listing, commands, HSM)
- WebSocket client for EventSocket (real-time events)

- [ ] **Step 1: Write tests for HubitatClient**

Test URL construction and model parsing (actual network calls need integration tests):

```swift
import XCTest
@testable import macOSBridge

final class HubitatClientTests: XCTestCase {

    func testClientInitialization() throws {
        let client = try HubitatClient(
            hubURL: URL(string: "http://192.168.1.100")!,
            appId: "42",
            accessToken: "test-token"
        )
        XCTAssertNotNil(client)
        XCTAssertFalse(client.isConnected)
    }

    func testMakerAPIURLConstruction() throws {
        let client = try HubitatClient(
            hubURL: URL(string: "http://192.168.1.100")!,
            appId: "42",
            accessToken: "test-token"
        )
        // Verify the base URL is constructed correctly
        let url = client.makeURL(endpoint: "devices/all")
        XCTAssertEqual(url?.host, "192.168.1.100")
        XCTAssertTrue(url?.path.contains("/apps/api/42/devices/all") ?? false)
        XCTAssertTrue(url?.query?.contains("access_token=test-token") ?? false)
    }

    func testCommandURLConstruction() throws {
        let client = try HubitatClient(
            hubURL: URL(string: "http://192.168.1.100")!,
            appId: "42",
            accessToken: "test-token"
        )
        let url = client.makeURL(endpoint: "devices/1/on")
        XCTAssertTrue(url?.path.contains("/apps/api/42/devices/1/on") ?? false)
    }

    func testEventSocketURLConstruction() throws {
        let client = try HubitatClient(
            hubURL: URL(string: "http://192.168.1.100")!,
            appId: "42",
            accessToken: "test-token"
        )
        XCTAssertEqual(client.eventSocketURL.absoluteString, "ws://192.168.1.100/eventsocket")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement HubitatClient**

Create `Itsyhome/Hubitat/HubitatClient.swift`:

```swift
//
//  HubitatClient.swift
//  Itsyhome
//
//  Hubitat Maker API (REST) + EventSocket (WebSocket) client
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatClient")

// MARK: - Client delegate

protocol HubitatClientDelegate: AnyObject {
    func clientDidConnect(_ client: HubitatClient)
    func clientDidDisconnect(_ client: HubitatClient, error: Error?)
    func client(_ client: HubitatClient, didReceiveDeviceEvent event: HubitatEvent)
    func client(_ client: HubitatClient, didEncounterError error: Error)
}

// MARK: - Client errors

enum HubitatClientError: LocalizedError {
    case notConnected
    case invalidURL(String)
    case invalidResponse
    case requestFailed(Int)
    case commandFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to Hubitat hub"
        case .invalidURL(let msg): return "Invalid URL: \(msg)"
        case .invalidResponse: return "Invalid response from Hubitat"
        case .requestFailed(let code): return "Request failed with status \(code)"
        case .commandFailed(let msg): return "Command failed: \(msg)"
        case .timeout: return "Request timed out"
        }
    }
}

// MARK: - Hubitat client

final class HubitatClient: NSObject {

    // MARK: - Properties

    private let hubURL: URL
    private let appId: String
    private let accessToken: String
    private let baseURL: URL        // http://hub_ip/apps/api/{appId}
    let eventSocketURL: URL         // ws://hub_ip/eventsocket

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 1.0

    private var pingTimer: Timer?

    /// Set of device IDs authorized in Maker API (for filtering EventSocket events)
    private(set) var authorizedDeviceIds: Set<String> = []

    weak var delegate: HubitatClientDelegate?

    private(set) var isConnected = false

    // MARK: - Initialization

    init(hubURL: URL, appId: String, accessToken: String) throws {
        guard let host = hubURL.host, !host.isEmpty else {
            throw HubitatClientError.invalidURL("URL has no host")
        }

        self.hubURL = hubURL
        self.appId = appId
        self.accessToken = accessToken

        // Build base URL for Maker API
        self.baseURL = hubURL.appendingPathComponent("apps/api/\(appId)")

        // Build EventSocket URL
        var wsComponents = URLComponents(url: hubURL, resolvingAgainstBaseURL: false)!
        wsComponents.scheme = "ws"
        wsComponents.path = "/eventsocket"
        self.eventSocketURL = wsComponents.url!

        super.init()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    deinit {
        disconnect()
    }

    // MARK: - URL construction

    /// Build a Maker API URL for the given endpoint
    func makeURL(endpoint: String) -> URL? {
        let url = baseURL.appendingPathComponent(endpoint)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "access_token", value: accessToken)]
        return components?.url
    }

    // MARK: - Connection (EventSocket WebSocket)

    func connect() async throws {
        logger.info("Connecting EventSocket to \(self.eventSocketURL.absoluteString, privacy: .public)")

        webSocketTask = urlSession.webSocketTask(with: eventSocketURL)
        webSocketTask?.resume()

        // Start receiving
        receiveMessage()

        // Mark connected after first successful receive or a short delay
        isConnected = true
        reconnectAttempts = 0

        startPing()
        delegate?.clientDidConnect(self)
    }

    func disconnect() {
        logger.info("Disconnecting from Hubitat")
        isConnected = false
        stopPing()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - WebSocket message handling

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage()

            case .failure(let error):
                logger.error("EventSocket receive error: \(error.localizedDescription)")
                self.handleDisconnection(error: error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        guard let event = HubitatEvent(json: json) else { return }

        // Only forward device events for authorized devices
        if event.isDeviceEvent {
            guard let deviceId = event.deviceId, authorizedDeviceIds.contains(deviceId) else {
                return
            }
            delegate?.client(self, didReceiveDeviceEvent: event)
        }
        // HSM and mode events can be forwarded as-is
        else if event.source == "LOCATION" {
            delegate?.client(self, didReceiveDeviceEvent: event)
        }
    }

    private func handleDisconnection(error: Error?) {
        isConnected = false
        stopPing()
        delegate?.clientDidDisconnect(self, error: error)
        scheduleReconnect()
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            logger.error("Max reconnection attempts reached")
            return
        }

        let delay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempts)) + Double.random(in: 0...1), 30.0)
        reconnectAttempts += 1

        logger.info("Scheduling EventSocket reconnect in \(delay, privacy: .public)s (attempt \(self.reconnectAttempts))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            Task { try? await self.connect() }
        }
    }

    // MARK: - Ping (keep-alive)

    private func startPing() {
        stopPing()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { error in
                if let error = error {
                    logger.warning("EventSocket ping failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    // MARK: - REST API Methods

    /// Generic GET request to Maker API
    private func get(endpoint: String) async throws -> Data {
        guard let url = makeURL(endpoint: endpoint) else {
            throw HubitatClientError.invalidURL("Cannot construct URL for \(endpoint)")
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HubitatClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw HubitatClientError.requestFailed(httpResponse.statusCode)
        }

        return data
    }

    /// Parse JSON array response
    private func getJSON(endpoint: String) async throws -> [[String: Any]] {
        let data = try await get(endpoint: endpoint)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw HubitatClientError.invalidResponse
        }
        return json
    }

    /// Parse JSON object response
    private func getJSONObject(endpoint: String) async throws -> [String: Any] {
        let data = try await get(endpoint: endpoint)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HubitatClientError.invalidResponse
        }
        return json
    }

    /// Get all authorized devices with full details
    func getAllDevices() async throws -> [HubitatDevice] {
        let json = try await getJSON(endpoint: "devices/all")
        let devices = json.compactMap { HubitatDevice(json: $0) }

        // Cache authorized device IDs for EventSocket filtering
        authorizedDeviceIds = Set(devices.map { $0.id })

        return devices
    }

    /// Get a single device with full details
    func getDevice(id: String) async throws -> HubitatDevice? {
        let json = try await getJSONObject(endpoint: "devices/\(id)")
        return HubitatDevice(json: json)
    }

    /// Send a command to a device (no parameters)
    func sendCommand(deviceId: String, command: String) async throws {
        logger.info("Sending command \(command) to device \(deviceId)")
        _ = try await get(endpoint: "devices/\(deviceId)/\(command)")
    }

    /// Send a command to a device with a single parameter
    func sendCommand(deviceId: String, command: String, value: String) async throws {
        logger.info("Sending command \(command)/\(value) to device \(deviceId)")
        // URL-encode the value for safety
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
        _ = try await get(endpoint: "devices/\(deviceId)/\(command)/\(encodedValue)")
    }

    /// Send a command with multiple comma-separated parameters
    func sendCommand(deviceId: String, command: String, values: [String]) async throws {
        let joined = values.joined(separator: ",")
        try await sendCommand(deviceId: deviceId, command: command, value: joined)
    }

    /// Get HSM status
    func getHSMStatus() async throws -> HubitatHSMStatus? {
        let json = try await getJSONObject(endpoint: "hsm")
        return HubitatHSMStatus(json: json)
    }

    /// Set HSM status
    func setHSM(status: String) async throws {
        _ = try await get(endpoint: "hsm/\(status)")
    }

    /// Get all hub modes
    func getModes() async throws -> [HubitatMode] {
        let json = try await getJSON(endpoint: "modes")
        return json.compactMap { HubitatMode(json: $0) }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension HubitatClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.info("EventSocket connection opened")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.info("EventSocket connection closed: \(closeCode.rawValue)")
        handleDisconnection(error: nil)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add Itsyhome/Hubitat/HubitatClient.swift macOSBridgeTests/Hubitat/HubitatClientTests.swift
git commit -m "feat(hubitat): add HubitatClient with Maker API REST + EventSocket WebSocket"
```

---

### Task 5: Device Mapper (HubitatDeviceMapper)

**Files:**
- Create: `Itsyhome/Hubitat/HubitatDeviceMapper.swift`
- Test: `macOSBridgeTests/Hubitat/HubitatDeviceMapperTests.swift`

This maps Hubitat capabilities → Itsyhome ServiceData, mirroring EntityMapper's role for HA.

- [ ] **Step 1: Write tests for device mapping**

```swift
import XCTest
@testable import macOSBridge

final class HubitatDeviceMapperTests: XCTestCase {

    var mapper: HubitatDeviceMapper!

    override func setUp() {
        mapper = HubitatDeviceMapper()
    }

    func testSwitchDeviceMapping() {
        let device = makeDevice(id: "1", name: "Test Switch", capabilities: ["Switch"], attributes: ["switch": "on"])
        mapper.loadDevices([device])
        let menuData = mapper.generateMenuData()
        XCTAssertEqual(menuData.accessories.count, 1)

        let service = menuData.accessories[0].services[0]
        XCTAssertNotNil(service.powerStateId)
        XCTAssertEqual(service.serviceType, ServiceTypes.switchService)
    }

    func testDimmerDeviceMapping() {
        let device = makeDevice(id: "2", name: "Test Dimmer",
                                capabilities: ["Switch", "SwitchLevel"],
                                attributes: ["switch": "on", "level": 75])
        mapper.loadDevices([device])
        let menuData = mapper.generateMenuData()

        let service = menuData.accessories[0].services[0]
        XCTAssertEqual(service.serviceType, ServiceTypes.lightbulb)
        XCTAssertNotNil(service.powerStateId)
        XCTAssertNotNil(service.brightnessId)
    }

    func testColorLightMapping() {
        let device = makeDevice(id: "3", name: "Color Bulb",
                                capabilities: ["Switch", "SwitchLevel", "ColorControl", "ColorTemperature"],
                                attributes: ["switch": "on", "level": 100, "hue": 50, "saturation": 80, "colorTemperature": 3500])
        mapper.loadDevices([device])
        let menuData = mapper.generateMenuData()

        let service = menuData.accessories[0].services[0]
        XCTAssertEqual(service.serviceType, ServiceTypes.lightbulb)
        XCTAssertNotNil(service.hueId)
        XCTAssertNotNil(service.saturationId)
        XCTAssertNotNil(service.colorTemperatureId)
    }

    func testLockMapping() {
        let device = makeDevice(id: "4", name: "Front Door",
                                capabilities: ["Lock"],
                                attributes: ["lock": "locked"])
        mapper.loadDevices([device])
        let menuData = mapper.generateMenuData()

        let service = menuData.accessories[0].services[0]
        XCTAssertEqual(service.serviceType, ServiceTypes.lock)
    }

    func testThermostatMapping() {
        let device = makeDevice(id: "5", name: "Main Thermostat",
                                capabilities: ["Thermostat", "TemperatureMeasurement"],
                                attributes: [
                                    "temperature": 72.0,
                                    "thermostatSetpoint": 70.0,
                                    "thermostatMode": "heat",
                                    "thermostatOperatingState": "heating"
                                ])
        mapper.loadDevices([device])
        let menuData = mapper.generateMenuData()

        let service = menuData.accessories[0].services[0]
        XCTAssertEqual(service.serviceType, ServiceTypes.thermostat)
    }

    func testCharacteristicUUIDConsistency() {
        // UUIDs should be deterministic across calls
        let uuid1 = mapper.characteristicUUID("1", "power")
        let uuid2 = mapper.characteristicUUID("1", "power")
        XCTAssertEqual(uuid1, uuid2)

        // Different characteristics should have different UUIDs
        let uuid3 = mapper.characteristicUUID("1", "brightness")
        XCTAssertNotEqual(uuid1, uuid3)
    }

    func testGetEntityIdFromCharacteristic() {
        let device = makeDevice(id: "10", name: "Test", capabilities: ["Switch"], attributes: ["switch": "on"])
        mapper.loadDevices([device])

        let powerUUID = mapper.characteristicUUID("10", "power")
        XCTAssertEqual(mapper.getDeviceIdFromCharacteristic(powerUUID), "10")
    }

    func testUpdateDeviceState() {
        let device = makeDevice(id: "1", name: "Test Switch", capabilities: ["Switch"], attributes: ["switch": "off"])
        mapper.loadDevices([device])

        // Verify initial state
        let powerUUID = mapper.characteristicUUID("1", "power")
        var values = mapper.getCharacteristicValues(for: "1")
        XCTAssertEqual(values[powerUUID] as? Bool, false)

        // Update state
        let event = HubitatEvent(json: [
            "source": "DEVICE", "name": "switch", "value": "on",
            "deviceId": "1", "displayName": "Test Switch"
        ])!
        mapper.updateDeviceAttribute(deviceId: "1", attributeName: event.name, value: event.value)

        values = mapper.getCharacteristicValues(for: "1")
        XCTAssertEqual(values[powerUUID] as? Bool, true)
    }

    // MARK: - Helpers

    private func makeDevice(id: String, name: String, capabilities: [String], attributes: [String: Any]) -> HubitatDevice {
        let json: [String: Any] = [
            "id": id,
            "name": name,
            "label": name,
            "type": "Virtual Device",
            "capabilities": capabilities,
            "attributes": attributes,
            "commands": []
        ]
        return HubitatDevice(json: json)!
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement HubitatDeviceMapper**

Create `Itsyhome/Hubitat/HubitatDeviceMapper.swift`. This is a large file (~400 lines) that mirrors `EntityMapper.swift`. Key sections:

1. **Device storage and caching** - stores `[String: HubitatDevice]` by device ID
2. **`generateMenuData()`** - produces `MenuData` from all devices
3. **`mapDeviceToServices()`** - inspects capabilities to create `ServiceData`
4. **`getCharacteristicValues(for:)`** - reads current attribute values mapped to characteristic UUIDs
5. **`updateDeviceAttribute()`** - updates a single attribute from EventSocket events
6. **Deterministic UUID generation** - same `deterministicUUID(for:)` approach as EntityMapper

The mapper should determine service type by inspecting capabilities in priority order:
- Has `ColorControl` → lightbulb (with hue/sat)
- Has `ColorTemperature` → lightbulb (with color temp)
- Has `SwitchLevel` → lightbulb (with brightness)
- Has `Thermostat` → thermostat
- Has `Lock` → lock
- Has `WindowShade` → windowCovering
- Has `GarageDoorControl` → garageDoor
- Has `Valve` → valve
- Has `FanControl` or `Fan` → fanV2
- Has `Switch` → switch (or outlet based on device type name)
- Has `TemperatureMeasurement` only → temperatureSensor
- Has `RelativeHumidityMeasurement` only → humiditySensor

Each device becomes one AccessoryData with one or more ServiceData entries.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add Itsyhome/Hubitat/HubitatDeviceMapper.swift macOSBridgeTests/Hubitat/HubitatDeviceMapperTests.swift
git commit -m "feat(hubitat): add HubitatDeviceMapper for capability-to-ServiceData mapping"
```

---

### Task 6: Platform Implementation (HubitatPlatform)

**Files:**
- Create: `Itsyhome/Hubitat/HubitatPlatform.swift`
- Create: `Itsyhome/Hubitat/HubitatPlatform+Actions.swift`
- Create: `Itsyhome/Hubitat/HubitatPlatform+Delegate.swift`
- Test: `macOSBridgeTests/Hubitat/HubitatPlatformTests.swift`

- [ ] **Step 1: Write tests for HubitatPlatform**

Basic structural tests (full integration tests need a hub):

```swift
import XCTest
@testable import macOSBridge

final class HubitatPlatformTests: XCTestCase {

    func testPlatformTypeIsHubitat() {
        let platform = HubitatPlatform()
        XCTAssertEqual(platform.platformType, .hubitat)
    }

    func testCapabilities() {
        let platform = HubitatPlatform()
        XCTAssertFalse(platform.capabilities.supportsMultipleHomes)
        XCTAssertFalse(platform.capabilities.supportsSceneStateTracking)
        XCTAssertFalse(platform.capabilities.supportsOutletInUse)
    }

    func testHasCamerasIsFalse() {
        let platform = HubitatPlatform()
        XCTAssertFalse(platform.hasCameras)
    }

    func testAvailableHomesIsEmpty() {
        let platform = HubitatPlatform()
        XCTAssertTrue(platform.availableHomes.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement HubitatPlatform.swift**

```swift
//
//  HubitatPlatform.swift
//  Itsyhome
//
//  SmartHomePlatform implementation for Hubitat Elevation
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatPlatform")

final class HubitatPlatform: SmartHomePlatform {

    // MARK: - SmartHomePlatform properties

    let platformType: SmartHomePlatformType = .hubitat
    let capabilities: PlatformCapabilities = .hubitat

    weak var delegate: SmartHomePlatformDelegate?

    var isConnected: Bool {
        client?.isConnected ?? false
    }

    var availableHomes: [HomeData] { [] }
    var selectedHomeIdentifier: UUID? {
        get { nil }
        set { }
    }

    var hasCameras: Bool { false }

    // MARK: - Internal properties

    var client: HubitatClient?
    let mapper = HubitatDeviceMapper()

    private var cachedMenuDataJSON: String?

    // MARK: - Connection

    func connect() async throws {
        guard let hubURL = HubitatAuthManager.shared.hubURL,
              let appId = HubitatAuthManager.shared.appId,
              let accessToken = HubitatAuthManager.shared.accessToken else {
            throw HubitatAuthError.notConfigured
        }

        logger.info("Connecting to Hubitat...")

        client = try HubitatClient(hubURL: hubURL, appId: appId, accessToken: accessToken)
        client?.delegate = self

        // Load devices first (populates authorizedDeviceIds for EventSocket filtering)
        await loadAllData()

        // Then connect EventSocket for real-time updates
        try await client?.connect()
    }

    func disconnect() {
        logger.info("Disconnecting from Hubitat")
        client?.disconnect()
        client = nil
    }

    // MARK: - Data loading

    private func loadAllData() async {
        guard let client = client else { return }

        do {
            let devices = try await client.getAllDevices()
            mapper.loadDevices(devices)

            let menuData = mapper.generateMenuData()
            if let jsonData = try? JSONEncoder().encode(menuData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                cachedMenuDataJSON = jsonString
                delegate?.platformDidUpdateMenuData(self, jsonString: jsonString)
            }

            logger.info("Loaded \(devices.count) Hubitat devices")
        } catch {
            logger.error("Failed to load data: \(error.localizedDescription)")
            delegate?.platformDidEncounterError(self, message: error.localizedDescription)
        }
    }

    func reloadData() {
        Task { await loadAllData() }
    }

    func getMenuDataJSON() -> String? {
        cachedMenuDataJSON
    }

    // MARK: - Cameras (not supported)

    func getCameraStream(cameraIdentifier: UUID) async throws -> CameraStreamInfo {
        throw HubitatClientError.notConnected
    }

    func getCameraSnapshotURL(cameraIdentifier: UUID) -> URL? {
        nil
    }

    // MARK: - Debug

    func getRawDataDump() -> String? {
        cachedMenuDataJSON
    }
}
```

- [ ] **Step 4: Implement HubitatPlatform+Actions.swift**

```swift
//
//  HubitatPlatform+Actions.swift
//  Itsyhome
//
//  Action execution: commands, characteristic reads/writes
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatPlatform")

extension HubitatPlatform {

    func executeScene(identifier: UUID) {
        // Hubitat doesn't expose scenes via Maker API
        logger.warning("Scenes not supported on Hubitat")
    }

    func readCharacteristic(identifier: UUID) {
        guard let deviceId = mapper.getDeviceIdFromCharacteristic(identifier) else { return }
        let values = mapper.getCharacteristicValues(for: deviceId)
        if let value = values[identifier] {
            delegate?.platformDidUpdateCharacteristic(self, identifier: identifier, value: value)
        }
    }

    func writeCharacteristic(identifier: UUID, value: Any) {
        guard let client = client else { return }
        guard let deviceId = mapper.getDeviceIdFromCharacteristic(identifier) else {
            logger.error("Device not found for characteristic: \(identifier)")
            return
        }

        let characteristicType = mapper.getCharacteristicType(for: identifier, deviceId: deviceId)
        logger.info("Writing '\(characteristicType)' = \(String(describing: value)) for device \(deviceId)")

        Task {
            do {
                try await writeValueToDevice(client: client, deviceId: deviceId,
                                             characteristicType: characteristicType, value: value)
            } catch {
                logger.error("Failed to write characteristic: \(error.localizedDescription)")
                delegate?.platformDidEncounterError(self, message: error.localizedDescription)
            }
        }
    }

    func getCharacteristicValue(identifier: UUID) -> Any? {
        guard let deviceId = mapper.getDeviceIdFromCharacteristic(identifier) else { return nil }
        return mapper.getCharacteristicValues(for: deviceId)[identifier]
    }

    // MARK: - Command dispatch

    private func writeValueToDevice(client: HubitatClient, deviceId: String,
                                    characteristicType: String, value: Any) async throws {
        switch characteristicType {
        case "power":
            if let isOn = value as? Bool {
                try await client.sendCommand(deviceId: deviceId, command: isOn ? "on" : "off")
            }

        case "brightness":
            let level: Int
            if let b = value as? Int { level = b }
            else if let b = value as? Double { level = Int(b) }
            else { return }
            // Hubitat setLevel takes 0-100 directly
            try await client.sendCommand(deviceId: deviceId, command: "setLevel", value: "\(level)")

        case "hue":
            let hue: Double
            if let h = value as? Double { hue = h }
            else if let h = value as? Int { hue = Double(h) }
            else { return }
            // Hubitat hue is 0-100 (not 0-360 like HA)
            let hubitatHue = Int(hue * 100.0 / 360.0)
            try await client.sendCommand(deviceId: deviceId, command: "setHue", value: "\(hubitatHue)")

        case "saturation":
            let sat: Int
            if let s = value as? Int { sat = s }
            else if let s = value as? Double { sat = Int(s) }
            else { return }
            try await client.sendCommand(deviceId: deviceId, command: "setSaturation", value: "\(sat)")

        case "color_temp":
            // Value comes in mireds from the UI, convert to Kelvin for Hubitat
            let mireds: Int
            if let m = value as? Int { mireds = m }
            else if let m = value as? Double { mireds = Int(m) }
            else { return }
            let kelvin = 1_000_000 / mireds
            try await client.sendCommand(deviceId: deviceId, command: "setColorTemperature", value: "\(kelvin)")

        case "lock_target":
            if let targetState = value as? Int {
                try await client.sendCommand(deviceId: deviceId, command: targetState == 1 ? "lock" : "unlock")
            }

        case "target_temp":
            let temp: Double
            if let d = value as? Double { temp = d }
            else if let i = value as? Int { temp = Double(i) }
            else { return }
            // Denormalize from Celsius if needed
            let setTemp = mapper.denormalizeTemperature(temp)
            try await client.sendCommand(deviceId: deviceId, command: "setThermostatSetpoint", value: "\(setTemp)")

        case "hvac_mode":
            let mode: String
            if let m = value as? String { mode = m }
            else if let m = value as? Int {
                switch m {
                case 0: mode = "off"
                case 1: mode = "heat"
                case 2: mode = "cool"
                case 3: mode = "auto"
                default: mode = "off"
                }
            } else { return }
            try await client.sendCommand(deviceId: deviceId, command: "setThermostatMode", value: mode)

        case "target_temp_high":
            let temp: Double
            if let d = value as? Double { temp = d }
            else if let i = value as? Int { temp = Double(i) }
            else { return }
            let setTemp = mapper.denormalizeTemperature(temp)
            try await client.sendCommand(deviceId: deviceId, command: "setCoolingSetpoint", value: "\(setTemp)")

        case "target_temp_low":
            let temp: Double
            if let d = value as? Double { temp = d }
            else if let i = value as? Int { temp = Double(i) }
            else { return }
            let setTemp = mapper.denormalizeTemperature(temp)
            try await client.sendCommand(deviceId: deviceId, command: "setHeatingSetpoint", value: "\(setTemp)")

        case "target_position":
            if let position = value as? Int {
                if position == -1 {
                    // Stop
                    try await client.sendCommand(deviceId: deviceId, command: "stopPositionChange")
                } else {
                    try await client.sendCommand(deviceId: deviceId, command: "setPosition", value: "\(position)")
                }
            }

        case "target_door":
            if let target = value as? Int {
                try await client.sendCommand(deviceId: deviceId, command: target == 0 ? "open" : "close")
            }

        case "valve_state":
            if let isOpen = value as? Bool {
                try await client.sendCommand(deviceId: deviceId, command: isOpen ? "open" : "close")
            } else if let intVal = value as? Int {
                try await client.sendCommand(deviceId: deviceId, command: intVal == 1 ? "open" : "close")
            }

        case "speed":
            if let speed = value as? Int {
                try await client.sendCommand(deviceId: deviceId, command: "setSpeed", value: "\(speed)")
            }

        case "alarm_target":
            let hsmStatus: String
            if let s = value as? String {
                hsmStatus = s
            } else if let i = value as? Int {
                switch i {
                case 0: hsmStatus = "armHome"
                case 1: hsmStatus = "armAway"
                case 2: hsmStatus = "armNight"
                case 3: hsmStatus = "disarm"
                default: return
                }
            } else { return }
            try await client.setHSM(status: hsmStatus)

        default:
            logger.warning("Unknown characteristic type for write: \(characteristicType)")
        }
    }
}
```

- [ ] **Step 5: Implement HubitatPlatform+Delegate.swift**

```swift
//
//  HubitatPlatform+Delegate.swift
//  Itsyhome
//
//  HubitatClientDelegate conformance
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatPlatform")

extension HubitatPlatform: HubitatClientDelegate {
    func clientDidConnect(_ client: HubitatClient) {
        logger.info("EventSocket connected")
    }

    func clientDidDisconnect(_ client: HubitatClient, error: Error?) {
        logger.info("EventSocket disconnected: \(error?.localizedDescription ?? "no error")")
        delegate?.platformDidDisconnect(self)
    }

    func client(_ client: HubitatClient, didReceiveDeviceEvent event: HubitatEvent) {
        guard let deviceId = event.deviceId else { return }
        logger.debug("Device event: \(deviceId) \(event.name) = \(event.value)")

        // Update mapper with new attribute value
        mapper.updateDeviceAttribute(deviceId: deviceId, attributeName: event.name, value: event.value)

        // Notify delegate of all characteristic changes for this device
        let values = mapper.getCharacteristicValues(for: deviceId)
        for (uuid, value) in values {
            delegate?.platformDidUpdateCharacteristic(self, identifier: uuid, value: value)
        }

        // Check for motion events
        if event.name == "motion" && event.value == "active" {
            // No camera association for Hubitat (no camera support)
        }
    }

    func client(_ client: HubitatClient, didEncounterError error: Error) {
        delegate?.platformDidEncounterError(self, message: error.localizedDescription)
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

- [ ] **Step 7: Commit**

```bash
git add Itsyhome/Hubitat/HubitatPlatform.swift Itsyhome/Hubitat/HubitatPlatform+Actions.swift \
    Itsyhome/Hubitat/HubitatPlatform+Delegate.swift macOSBridgeTests/Hubitat/HubitatPlatformTests.swift
git commit -m "feat(hubitat): add HubitatPlatform implementing SmartHomePlatform protocol"
```

---

### Task 7: Mac2iOS Bridge Adapter (HubitatBridge)

**Files:**
- Create: `macOSBridge/Hubitat/HubitatBridge.swift`

- [ ] **Step 1: Implement HubitatBridge**

Mirror `HomeAssistantBridge.swift` exactly:

```swift
//
//  HubitatBridge.swift
//  macOSBridge
//
//  Adapter that implements Mac2iOS protocol for Hubitat
//

import Foundation

class HubitatBridge: NSObject, Mac2iOS {

    private let platform: HubitatPlatform

    init(platform: HubitatPlatform) {
        self.platform = platform
        super.init()
    }

    var homes: [HomeInfo] {
        let homeId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        return [HomeInfo(uniqueIdentifier: homeId, name: "Hubitat", isPrimary: true)]
    }

    var selectedHomeIdentifier: UUID? {
        get { nil }
        set { }
    }

    var rooms: [RoomInfo] { [] }
    var accessories: [AccessoryInfo] { [] }
    var scenes: [SceneInfo] { [] }

    func reloadHomeKit() { platform.reloadData() }
    func executeScene(identifier: UUID) { platform.executeScene(identifier: identifier) }
    func readCharacteristic(identifier: UUID) { platform.readCharacteristic(identifier: identifier) }
    func writeCharacteristic(identifier: UUID, value: Any) { platform.writeCharacteristic(identifier: identifier, value: value) }
    func getCharacteristicValue(identifier: UUID) -> Any? { platform.getCharacteristicValue(identifier: identifier) }

    func openCameraWindow() {
        NotificationCenter.default.post(name: .requestOpenCameraWindow, object: nil)
    }

    func closeCameraWindow() {
        NotificationCenter.default.post(name: .requestCloseCameraWindow, object: nil)
    }

    func setCameraWindowHidden(_ hidden: Bool) {
        NotificationCenter.default.post(name: .requestSetCameraWindowHidden, object: nil, userInfo: ["hidden": hidden])
    }

    func getRawHomeKitDump() -> String? { platform.getRawDataDump() }

    func getCameraDebugJSON(entityId: String?, completion: @escaping (String?) -> Void) {
        completion(nil) // No camera support
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add macOSBridge/Hubitat/HubitatBridge.swift
git commit -m "feat(hubitat): add HubitatBridge Mac2iOS adapter"
```

---

### Task 8: Wire Into MacOSController

**Files:**
- Modify: `macOSBridge/MacOSController.swift`

This is the most critical integration task. The existing controller uses `if/else` checks (not switch statements) in most places for platform routing. Every location must be updated to handle `.hubitat`. The following steps enumerate **every** integration point by line reference.

- [ ] **Step 1: Add Hubitat properties (near line 43)**

Add alongside the existing `homeAssistantPlatform` and `homeAssistantBridge`:

```swift
private var hubitatPlatform: HubitatPlatform?
private var hubitatBridge: HubitatBridge?
private var isConnectingToHubitat = false
```

Also add notification observer and connect controller properties:

```swift
private var hubitatConnectController: HubitatConnectWindowController?
```

- [ ] **Step 2: Update `activeBridge` property (line 54)**

The current code only checks `.homeAssistant`. Change to a three-way check:

```swift
var activeBridge: Mac2iOS? {
    switch PlatformManager.shared.selectedPlatform {
    case .homeAssistant:
        return homeAssistantBridge
    case .hubitat:
        return hubitatBridge
    case .homeKit, .none:
        return iOSBridge
    }
}
```

- [ ] **Step 3: Add startup connection for Hubitat (near line 202)**

After the existing `if PlatformManager.shared.selectedPlatform == .homeAssistant` block, add:

```swift
if PlatformManager.shared.selectedPlatform == .hubitat {
    if HubitatAuthManager.shared.isConfigured {
        connectToHubitat()
    } else {
        // Hubitat selected but not configured - open settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            SettingsWindowController.shared.showSection(.hubitat)
        }
    }
}
```

- [ ] **Step 4: Add `HubitatCredentialsChanged` notification observer (near line 167)**

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleHubitatCredentialsChanged),
    name: NSNotification.Name("HubitatCredentialsChanged"),
    object: nil
)
```

And the handler:

```swift
@objc private func handleHubitatCredentialsChanged() {
    if HubitatAuthManager.shared.isConfigured {
        connectToHubitat()
    } else {
        disconnectFromHubitat()
    }
}
```

- [ ] **Step 5: Update `handleSystemWake()` (line 258)**

The current method guards on `.homeAssistant` only. Add Hubitat reconnection:

```swift
@objc private func handleSystemWake() {
    // Re-evaluate SSID after wake...
    // (existing SSID code stays)

    // Reconnect platform if needed
    let platform = PlatformManager.shared.selectedPlatform
    if platform == .homeAssistant {
        guard HAAuthManager.shared.isConfigured else { return }
        guard homeAssistantPlatform?.isConnected != true else { return }
        disconnectFromHomeAssistant()
        connectToHomeAssistant()
    } else if platform == .hubitat {
        guard HubitatAuthManager.shared.isConfigured else { return }
        guard hubitatPlatform?.isConnected != true else { return }
        disconnectFromHubitat()
        connectToHubitat()
    }
}
```

- [ ] **Step 6: Update network monitor (near line 279)**

The network availability handler reconnects HA. Add Hubitat:

```swift
// Inside the network monitor's pathUpdateHandler:
let platform = PlatformManager.shared.selectedPlatform
if platform == .homeAssistant {
    // existing HA reconnection code
} else if platform == .hubitat {
    guard HubitatAuthManager.shared.isConfigured else { return }
    guard self.hubitatPlatform?.isConnected != true else { return }
    guard !self.isConnectingToHubitat else { return }
    self.disconnectFromHubitat()
    self.connectToHubitat()
}
```

- [ ] **Step 7: Add `connectToHubitat()` and `disconnectFromHubitat()` methods**

Mirror `connectToHomeAssistant()` (line 382) and `disconnectFromHomeAssistant()` (line 413):

```swift
private func connectToHubitat() {
    guard PlatformManager.shared.selectedPlatform == .hubitat else { return }
    guard HubitatAuthManager.shared.isConfigured else { return }

    StartupLogger.log("Connecting to Hubitat...")
    isConnectingToHubitat = true

    if hubitatPlatform == nil {
        hubitatPlatform = HubitatPlatform()
        hubitatPlatform?.delegate = self
        hubitatBridge = HubitatBridge(platform: hubitatPlatform!)
    }

    actionEngine.bridge = hubitatBridge

    Task {
        do {
            try await hubitatPlatform?.connect()
            StartupLogger.log("Connected to Hubitat")
            await MainActor.run { isConnectingToHubitat = false }
        } catch {
            StartupLogger.log("Failed to connect to Hubitat: \(error.localizedDescription)")
            await MainActor.run { isConnectingToHubitat = false }
        }
    }
}

private func disconnectFromHubitat() {
    hubitatPlatform?.disconnect()
    hubitatPlatform = nil
    hubitatBridge = nil
    StartupLogger.log("Disconnected from Hubitat")
}
```

- [ ] **Step 8: Update action methods (lines 467-495)**

Each of these uses `if platform == .homeAssistant { ... } else { ... }` which falls through to HomeKit. Change to three-way checks:

```swift
func executeScene(identifier: UUID) {
    switch PlatformManager.shared.selectedPlatform {
    case .homeAssistant: homeAssistantPlatform?.executeScene(identifier: identifier)
    case .hubitat: hubitatPlatform?.executeScene(identifier: identifier)
    case .homeKit, .none: iOSBridge?.executeScene(identifier: identifier)
    }
}

func readCharacteristic(identifier: UUID) {
    switch PlatformManager.shared.selectedPlatform {
    case .homeAssistant: homeAssistantPlatform?.readCharacteristic(identifier: identifier)
    case .hubitat: hubitatPlatform?.readCharacteristic(identifier: identifier)
    case .homeKit, .none: iOSBridge?.readCharacteristic(identifier: identifier)
    }
}

func writeCharacteristic(identifier: UUID, value: Any) {
    switch PlatformManager.shared.selectedPlatform {
    case .homeAssistant: homeAssistantPlatform?.writeCharacteristic(identifier: identifier, value: value)
    case .hubitat: hubitatPlatform?.writeCharacteristic(identifier: identifier, value: value)
    case .homeKit, .none: iOSBridge?.writeCharacteristic(identifier: identifier, value: value)
    }
}

func getCharacteristicValue(identifier: UUID) -> Any? {
    switch PlatformManager.shared.selectedPlatform {
    case .homeAssistant: return homeAssistantPlatform?.getCharacteristicValue(identifier: identifier)
    case .hubitat: return hubitatPlatform?.getCharacteristicValue(identifier: identifier)
    case .homeKit, .none: return iOSBridge?.getCharacteristicValue(identifier: identifier)
    }
}
```

- [ ] **Step 9: Update `reloadMenuWithJSON` guard (line 607)**

Currently ignores HomeKit data when HA is selected. Also ignore for Hubitat:

```swift
@objc public func reloadMenuWithJSON(_ jsonString: String) {
    let platform = PlatformManager.shared.selectedPlatform
    if platform == .homeAssistant || platform == .hubitat {
        StartupLogger.log("Ignoring HomeKit JSON - \(platform.rawValue) is selected")
        return
    }
    // ... rest of method
}
```

- [ ] **Step 10: Update `updateStatusItemIcon()` (line 571)**

```swift
let iconName: String
switch PlatformManager.shared.selectedPlatform {
case .homeAssistant: iconName = "HAMenuBarIcon"
case .hubitat: iconName = "HubitatMenuBarIcon"  // or reuse "MenuBarIcon" if no custom icon
case .homeKit, .none: iconName = "MenuBarIcon"
}
```

Note: If no custom Hubitat menu bar icon is available, reuse "MenuBarIcon" for now.

- [ ] **Step 11: Update `setupMenu()` switch statement (line 585)**

This is exhaustive and will cause a compiler error without a `.hubitat` case:

```swift
case .hubitat:
    loadingText = String(localized: "menu.loading.hubitat", defaultValue: "Connecting to Hubitat...", bundle: .macOSBridge)
```

- [ ] **Step 12: Update entity category filter reload (line 531)**

```swift
if PlatformManager.shared.selectedPlatform == .homeAssistant {
    homeAssistantPlatform?.reloadData()
} else if PlatformManager.shared.selectedPlatform == .hubitat {
    hubitatPlatform?.reloadData()
}
```

- [ ] **Step 13: Update `refreshHomeKit` (line 919)**

Add Hubitat case:

```swift
} else if PlatformManager.shared.selectedPlatform == .hubitat {
    if hubitatPlatform?.isConnected == true {
        hubitatPlatform?.reloadData()
    } else {
        connectToHubitat()
    }
}
```

- [ ] **Step 14: Update camera debug log (line 821)**

Update the platform label ternary to include Hubitat:

```swift
let platformLabel: String
switch PlatformManager.shared.selectedPlatform {
case .homeAssistant: platformLabel = "HA"
case .hubitat: platformLabel = "HUB"
case .homeKit, .none: platformLabel = "HK"
}
```

- [ ] **Step 15: Update camera data posting (line 823)**

Camera data should only be posted for HA (Hubitat has no cameras):

```swift
if PlatformManager.shared.selectedPlatform == .homeAssistant && !data.cameras.isEmpty {
```

(No change needed - this already correctly limits to `.homeAssistant`.)

- [ ] **Step 16: Add `PlatformPickerDelegate` conformance for Hubitat**

Add `platformPickerDidSelectHubitat()` handler to show `HubitatConnectWindowController`.

- [ ] **Step 17: Compile and verify no errors**

Run: `xcodebuild build -project Itsyhome.xcodeproj -scheme Itsyhome -destination 'platform=macOS' 2>&1 | tail -20`

- [ ] **Step 18: Commit**

```bash
git add macOSBridge/MacOSController.swift
git commit -m "feat(hubitat): wire HubitatPlatform into MacOSController (all 15+ integration points)"
```

---

### Task 9: Onboarding UI (Platform Picker + Connect Window)

**Files:**
- Modify: `macOSBridge/PlatformPicker/PlatformPickerWindowController.swift`
- Create: `macOSBridge/PlatformPicker/HubitatConnectWindowController.swift`
- Create: `macOSBridge/PlatformPicker/HubitatSuccessWindowController.swift` (optional, can reuse HA pattern)
- Add: `macOSBridge/Resources/hubitat.png` (Hubitat logo icon)

- [ ] **Step 1: Add Hubitat icon asset**

Add a `hubitat.png` icon to `macOSBridge/Resources/` (similar to the existing `ha` icon for Home Assistant). This should be a clean Hubitat logo at 64x64 and 128x128 resolution.

- [ ] **Step 2: Add Hubitat card to PlatformPickerWindowController**

Add a third card to the onboarding picker. The `PlatformPickerView` currently uses an `NSStackView` with two cards. Add a `hubitatCard`:

```swift
// In PlatformPickerView
private let hubitatCard: PlatformCard

// In init:
hubitatCard = PlatformCard(
    title: String(localized: "settings.general.hubitat", defaultValue: "Hubitat", bundle: .macOSBridge),
    subtitle: String(localized: "onboarding.hubitat_subtitle", defaultValue: "Hubitat Elevation smart home hub", bundle: .macOSBridge),
    icon: pluginBundle.image(forResource: "hubitat") ?? NSImage()
)

// Add to cardsStack:
let cardsStack = NSStackView(views: [homeKitCard, homeAssistantCard, hubitatCard])

// Card action:
hubitatCard.onClick = { [weak self] in self?.onHubitatSelected?() }
```

Update the `PlatformPickerDelegate`:
```swift
protocol PlatformPickerDelegate: AnyObject {
    func platformPickerDidSelectHomeKit()
    func platformPickerDidSelectHomeAssistant()
    func platformPickerDidSelectHubitat()
}
```

Adjust window width to accommodate 3 cards (e.g., 680 from 500).

- [ ] **Step 3: Create HubitatConnectWindowController**

Mirror `HAConnectWindowController` but with three fields:
- Hub URL (placeholder: `http://192.168.1.xxx`)
- Maker API App ID (placeholder: `e.g., 42`)
- Access Token (secure field)
- Help text: "Configure Maker API in your Hubitat hub: Apps > Maker API"

```swift
protocol HubitatConnectDelegate: AnyObject {
    func hubitatConnectDidSucceed(hubURL: String, appId: String, accessToken: String, deviceCount: Int)
    func hubitatConnectDidCancel()
}
```

- [ ] **Step 4: Wire delegate in MacOSController**

Handle the `platformPickerDidSelectHubitat()` delegate call → show `HubitatConnectWindowController` → on success, call `PlatformManager.shared.selectHubitat()`.

- [ ] **Step 5: Compile and test onboarding flow visually**

- [ ] **Step 6: Commit**

```bash
git add macOSBridge/PlatformPicker/ macOSBridge/Resources/hubitat.png
git commit -m "feat(hubitat): add Hubitat to platform picker and onboarding flow"
```

---

### Task 10: Settings UI (HubitatSection)

**Files:**
- Create: `macOSBridge/Settings/Sections/HubitatSection.swift`
- Modify: `macOSBridge/Settings/SettingsView.swift`
- Modify: `macOSBridge/Settings/Sections/GeneralSection.swift`

- [ ] **Step 1: Create HubitatSection**

Mirror `HomeAssistantSection.swift` with three input fields (hub URL, app ID, access token), connection status indicator, and connect/disconnect buttons. No entity category filter (Hubitat doesn't have entity categories).

- [ ] **Step 2: Add `.hubitat` to SettingsView Section enum**

```swift
private enum Section: Int, CaseIterable {
    case general
    case homeAssistant
    case hubitat        // new
    case accessories
    case cameras
    case networks
    case advanced
    case deeplinks
}
```

Add title, icon, `isAvailableForCurrentPlatform` (return `platform == .hubitat`), and section instantiation.

- [ ] **Step 3: Add Hubitat card to GeneralSection platform picker**

Add a third `PlatformCardButton` for Hubitat alongside the existing HomeKit and HA cards. Handle the `.hubitat` case in `platformCardTapped()`.

- [ ] **Step 4: Compile and verify settings UI**

- [ ] **Step 5: Commit**

```bash
git add macOSBridge/Settings/Sections/HubitatSection.swift macOSBridge/Settings/SettingsView.swift \
    macOSBridge/Settings/Sections/GeneralSection.swift
git commit -m "feat(hubitat): add Hubitat settings section and platform picker card"
```

---

### Task 11: XcodeGen Configuration (project.yml)

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Add Hubitat source path to both targets**

In the `Itsyhome` target sources:
```yaml
- path: Itsyhome/Hubitat
```

In the `macOSBridge` target sources:
```yaml
- path: Itsyhome/Hubitat
  buildPhase: sources
```

In the `macOSBridgeTests` target sources:
```yaml
- path: Itsyhome/Hubitat
  buildPhase: sources
```

- [ ] **Step 2: Regenerate Xcode project**

Run: `xcodegen generate`

- [ ] **Step 3: Build and run tests**

Run: `xcodebuild test -project Itsyhome.xcodeproj -scheme Itsyhome -destination 'platform=macOS'`

- [ ] **Step 4: Commit**

```bash
git add project.yml Itsyhome.xcodeproj
git commit -m "feat(hubitat): add Hubitat sources to project.yml and regenerate xcodeproj"
```

---

### Task 12: Integration Testing & Polish

**Files:**
- All Hubitat files

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -project Itsyhome.xcodeproj -scheme Itsyhome -destination 'platform=macOS' 2>&1 | grep -E '(Test Suite|Tests|FAIL|PASS)'
```

- [ ] **Step 2: Verify build succeeds for all targets**

```bash
xcodebuild build -project Itsyhome.xcodeproj -scheme Itsyhome -destination 'platform=macOS'
```

- [ ] **Step 3: Manual review of all new files**

Verify:
- No hardcoded credentials or test data
- Proper error handling on all network calls
- Thread safety (locks where needed)
- Memory management (weak references, no retain cycles)
- Consistent logging (using os.log)
- Consistent code style with existing HA integration

- [ ] **Step 4: Final commit if any polish needed**

---

## Task Dependency Order

```
Task 1 (Platform Registration)
    ↓
Task 2 (AuthManager)
    ↓
Task 3 (Models)
    ↓
Task 4 (Client)
    ↓
Task 5 (DeviceMapper)
    ↓
Task 6 (Platform)
    ↓
Task 7 (Bridge)
    ↓
Task 8 (MacOSController wiring)
    ↓
Task 11 (project.yml) ← can be done earlier, after Task 1
    ↓
Task 9 (Onboarding UI)  ← parallel with Task 10
Task 10 (Settings UI)   ← parallel with Task 9
    ↓
Task 12 (Integration Testing)
```

Tasks 9 and 10 are independent of each other and can be parallelized. Task 11 (project.yml) should ideally be done early (after Task 1) so that subsequent files are immediately included in the build, but it can also be batched.

## Notes for Implementers

1. **Hubitat hue range**: Hubitat uses 0-100 for hue (not 0-360). Convert: write `hue * 100 / 360`, read `hue * 360 / 100`. The mapper must convert both directions.
2. **Color temperature**: Hubitat uses Kelvin natively. The app uses mireds internally (for HomeKit compat). Convert: `mireds = 1_000_000 / kelvin`, `kelvin = 1_000_000 / mireds`.
3. **Temperature units**: Hubitat reports in the hub's configured unit (usually Fahrenheit in US). Since there's no centralized config endpoint, detect the unit from the first temperature attribute's `unit` field in events, or default to Fahrenheit for US hubs. Normalize to Celsius internally, same as HA. Store the detected unit in the mapper.
4. **No rooms/areas**: Hubitat Maker API doesn't expose rooms. All devices appear in a flat list (no room grouping). The `RoomData` array in `MenuData` will be empty.
5. **Device ID types**: Hubitat device IDs can come as integers or strings in JSON. Always normalize to String.
6. **EventSocket filtering**: The EventSocket delivers ALL hub events. Filter to only `authorizedDeviceIds` (populated from Maker API device list) to avoid processing events for devices the user hasn't exposed.
7. **No WebRTC/camera support**: Hubitat has no camera API. `hasCameras` returns false, camera methods throw/return nil.
8. **HSM mapping**: `armedAway` → alarm mode 1, `armedHome` → mode 0, `armedNight` → mode 2, `disarmed` → mode 3.
9. **`deterministicUUID` is private on EntityMapper**: `HubitatDeviceMapper` needs its own copy of this method (same SHA-256 based UUID generation). Do NOT make EntityMapper's method public — keep the mappers independent. The implementation is: SHA-256 hash the input string, take the first 16 bytes, set UUID version/variant bits.
10. **Fan speed**: Hubitat's `setSpeed` command takes string values ("low", "medium-low", "medium", "medium-high", "high", "on", "off", "auto"), NOT numeric percentages. If the device has `FanControl` capability, use `setSpeed` with string mapping from percentage ranges. Alternatively, some fans support `setLevel` (0-100) via `SwitchLevel` capability — prefer that when available.
11. **Credential change notification**: `HubitatSection` must post `NSNotification.Name("HubitatCredentialsChanged")` when credentials are saved or cleared, mirroring the `HomeAssistantCredentialsChanged` pattern.
12. **Network auto-switch**: Not implemented for Hubitat initially (LAN-only, single hub). The `setupNetworkAutoSwitch()` method currently only handles HA server URL overrides. Note this as a conscious omission — can be added later if users need per-network hub addresses.
