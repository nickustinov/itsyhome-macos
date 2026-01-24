# Itsyhome

[![Tests](https://github.com/nickustinov/itsyhome-macos/actions/workflows/test.yml/badge.svg)](https://github.com/nickustinov/itsyhome-macos/actions/workflows/test.yml)

![Itsyhome app demo](https://itsyhome.app/itsyhome-demo.gif)

A native macOS menu bar app for controlling your HomeKit smart home devices.

**[itsyhome.app](https://itsyhome.app)**

## Features

- **Menu bar access** - Control your smart home from the macOS menu bar
- **Full HomeKit support** - Lights, switches, outlets, fans, thermostats, AC units, blinds, locks, garage doors, humidifiers, air purifiers, valves, cameras, and security systems
- **Scenes** - Execute and toggle HomeKit scenes with state tracking
- **Favourites** - Pin frequently used devices and scenes to the top of the menu
- **Multi-home support** - Switch between multiple HomeKit homes
- **Native experience** - Built with AppKit for a true macOS look and feel
- **Device groups** - Create custom groups to control multiple devices at once *(Pro)*
- **iCloud sync** - Sync favourites and settings across your Macs *(Pro)*
- **Deeplinks** - Control devices from Shortcuts, Alfred, Raycast, Stream Deck *(Pro)*
- **Cameras** - Live video feed with overlay action buttons to control accessories *(Pro)*
- **Webhooks/CLI** - Built-in HTTP server with a dedicated CLI tool *(Pro)*

## Supported devices

| Device type | Features |
|-------------|----------|
| Lights | On/off, brightness slider |
| Switches & Outlets | On/off toggle |
| Fans | On/off, speed control |
| Thermostats | Current temp, target temp slider, heat/cool mode |
| AC / Heater-Cooler | Power, mode selection, temperature control |
| Blinds / Window coverings | Position slider |
| Locks | Lock/unlock toggle |
| Garage doors | Open/close with status |
| Humidifiers & Dehumidifiers | Power, mode, target humidity |
| Air purifiers | Power, mode, speed control |
| Valves | Open/close toggle |
| Security systems | Arm home/away/night, disarm |
| Cameras | Live video feed with overlay action buttons to control accessories *(Pro)* |
| Temperature & Humidity sensors | Summary display per room |

## Itsyhome Pro

### iCloud sync

Sync your favourites, hidden items, device groups, and shortcuts across all your Macs.

### Cameras

View live video feeds from your HomeKit cameras directly in the menu bar. Overlay action buttons let you control nearby accessories without leaving the camera view — toggle lights and outlets, open garage doors and gates, or lock and unlock doors.

### Device groups

Create custom groups of devices to control multiple devices at once. Groups appear in your menu bar and can be controlled via deeplinks and webhooks.

### Deeplinks

Control your HomeKit devices from external apps using URL schemes. Perfect for Shortcuts, Alfred, Raycast, Stream Deck, and other automation tools.

**URL format:**
```
itsyhome://<action>/<target>
```

**Actions:**

| Action | URL format | Example |
|--------|-----------|---------|
| Toggle | `itsyhome://toggle/<Room>/<Device>` | `itsyhome://toggle/Office/Spotlights` |
| Turn on | `itsyhome://on/<Room>/<Device>` | `itsyhome://on/Kitchen/Light` |
| Turn off | `itsyhome://off/<Room>/<Device>` | `itsyhome://off/Bedroom/Lamp` |
| Brightness | `itsyhome://brightness/<0-100>/<Room>/<Device>` | `itsyhome://brightness/50/Office/Lamp` |
| Position | `itsyhome://position/<0-100>/<Room>/<Device>` | `itsyhome://position/75/Living%20Room/Blinds` |
| Temperature | `itsyhome://temp/<degrees>/<Room>/<Device>` | `itsyhome://temp/22/Hallway/Thermostat` |
| Color | `itsyhome://color/<hue>/<saturation>/<Room>/<Device>` | `itsyhome://color/120/100/Bedroom/Light` |
| Scene | `itsyhome://scene/<Scene%20Name>` | `itsyhome://scene/Goodnight` |
| Lock | `itsyhome://lock/<Room>/<Device>` | `itsyhome://lock/Front%20Door` |
| Unlock | `itsyhome://unlock/<Room>/<Device>` | `itsyhome://unlock/Front%20Door` |
| Open | `itsyhome://open/<Room>/<Device>` | `itsyhome://open/Garage/Door` |
| Close | `itsyhome://close/<Room>/<Device>` | `itsyhome://close/Bedroom/Blinds` |

**Target formats:**

- `Room/Device` - Device in specific room (e.g., `Office/Spotlights`)
- `group.Name` - All devices in a group (e.g., `group.Office%20Lights`)

**Testing from terminal:**
```bash
open "itsyhome://toggle/Office/Spotlights"
open "itsyhome://toggle/group.Office%20Lights"
open "itsyhome://scene/Goodnight"
open "itsyhome://brightness/50/Bedroom/Lamp"
```

**Note:** Spaces in room or device names must be URL-encoded as `%20`.

### Webhooks/CLI

A built-in HTTP server that lets you control and query your HomeKit devices from any tool on your network — terminal, scripts, other apps, or the dedicated [itsyhome CLI](https://github.com/nickustinov/itsyhome-cli).

Enable the server in Settings → Webhooks/CLI. Default port: `8423`.

**Control endpoints:**

```bash
curl http://localhost:8423/toggle/Office/Spotlights
curl http://localhost:8423/on/Kitchen/Light
curl http://localhost:8423/off/Bedroom/Lamp
curl http://localhost:8423/brightness/50/Office/Lamp
curl http://localhost:8423/position/75/Living%20Room/Blinds
curl http://localhost:8423/temp/22/Hallway/Thermostat
curl http://localhost:8423/color/120/100/Bedroom/Light
curl http://localhost:8423/scene/Goodnight
curl http://localhost:8423/lock/Front%20Door
curl http://localhost:8423/unlock/Front%20Door
curl http://localhost:8423/open/Garage/Door
curl http://localhost:8423/close/Bedroom/Blinds
```

**Query endpoints:**

| Endpoint | Description |
|----------|-------------|
| `/status` | Home summary (rooms, devices, reachable/unreachable counts) |
| `/list/rooms` | List all rooms |
| `/list/devices` | List all devices with type and reachability |
| `/list/devices/<room>` | List devices in a specific room |
| `/list/scenes` | List all scenes |
| `/list/groups` | List all device groups |
| `/info/<target>` | Detailed device/room info with current state |

**Response format:**

```json
{"status": "success"}
{"status": "error", "message": "device not found"}
```

**CLI tool:**

Install the dedicated CLI for a better terminal experience:

```bash
brew install nickustinov/tap/itsyhome
```

See [itsyhome-cli](https://github.com/nickustinov/itsyhome-cli) for full documentation.

### Stream Deck

Control your HomeKit devices directly from an Elgato Stream Deck using the [Itsyhome Stream Deck plugin](https://github.com/nickustinov/itsyhome-streamdeck). Requires the webhook server to be enabled.

**Actions:**

| Action | Description |
|--------|-------------|
| Toggle device | Toggle any device on/off with device-type-aware icons |
| Execute scene | Trigger a HomeKit scene |
| Set brightness | Set a light to a specific brightness level |
| Lock | Lock/unlock with optimistic feedback |
| AC | Toggle thermostat/AC with mode-aware icons (heat/cool/auto) |
| Status | Display temperature or humidity readings |
| Blinds | Open/close blinds with position display |
| Garage door | Open/close garage door with state feedback |

Features include color-coded icons per device type, live state polling, optimistic updates for slow devices (locks, garage doors), and optional labels for multi-button setups.

See [itsyhome-streamdeck](https://github.com/nickustinov/itsyhome-streamdeck) for setup and development.

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation
- Apple Developer account with HomeKit entitlement

## Setup

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Clone the repository

```bash
git clone https://github.com/nickustinov/itsyhome-macos.git
cd itsyhome-macos
```

### 3. Configure your bundle ID and team

Edit `project.yml` and update:

```yaml
options:
  bundleIdPrefix: com.yourdomain  # Your reverse domain

settings:
  base:
    DEVELOPMENT_TEAM: YOUR_TEAM_ID  # Uncomment and set your team ID
```

### 4. Generate the Xcode project

```bash
xcodegen generate
```

### 5. Open and run

```bash
open Itsyhome.xcodeproj
```

Select the **Itsyhome** scheme and run on **My Mac (Mac Catalyst)**.

## Architecture

This app uses Mac Catalyst with a native AppKit plugin for the menu bar:

```
Itsyhome/
├── iOS/                    # Main Catalyst app (hidden, headless)
│   ├── AppDelegate.swift   # App lifecycle
│   ├── HomeKitManager.swift # HomeKit integration
│   └── SceneDelegate.swift
├── Shared/                 # Shared code between iOS and macOS
│   └── BridgeProtocols.swift
└── Resources/

macOSBridge/                # Native AppKit plugin
├── MacOSController.swift   # Menu bar controller
├── DesignSystem/           # Design tokens and custom controls
├── MenuItems/              # Custom menu item views
└── Settings/               # Preferences and favourites
```

The iOS/Catalyst app runs headless and manages HomeKit communication. It loads the `macOSBridge` plugin which provides the native AppKit menu bar interface.

## How it works

1. The Catalyst app initializes HomeKit and monitors for device updates
2. Device data is serialized to JSON and passed to the macOS plugin
3. The plugin renders custom `NSMenuItem` views with controls
4. User interactions are sent back to the Catalyst app to execute HomeKit commands

## Building

The project uses XcodeGen to generate the Xcode project from `project.yml`. After making changes to project configuration:

```bash
xcodegen generate
```

## Testing

The project includes unit tests for the macOSBridge plugin. Run tests with:

```bash
xcodebuild test -scheme macOSBridgeTests -destination "platform=macOS"
```

Test coverage includes:
- `LocalChangeNotifiableTests` - Notification protocol for syncing menu items
- `ValueConversionTests` - Type conversion utilities for HomeKit values
- `SwitchMenuItemTests` - Menu item behaviour and protocol conformance

## HomeKit entitlement

This app requires the HomeKit entitlement. You'll need to:

1. Enable HomeKit capability in your Apple Developer account
2. Create an App ID with HomeKit enabled
3. The entitlement is already configured in `Itsyhome/Itsyhome.entitlements`

## License

MIT License © 2026 Nick Ustinov - see [LICENSE](LICENSE) for details.

## Author

**Nick Ustinov**
- Email: nickustinov@gmail.com
- Website: [itsyhome.app](https://itsyhome.app)
- GitHub: [@nickustinov](https://github.com/nickustinov)

## Links

- **Website**: [itsyhome.app](https://itsyhome.app)
- **Issues**: [GitHub Issues](https://github.com/nickustinov/itsyhome-macos/issues)

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
