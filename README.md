# Itsyhome

A native macOS menu bar app for controlling your HomeKit smart home devices.

**[itsyhome.app](https://itsyhome.app)** · Free forever

## Features

- **Menu bar access** - Control your smart home from the macOS menu bar
- **Full HomeKit support** - Lights, switches, outlets, fans, thermostats, AC units, blinds, locks, garage doors, and contact sensors
- **Scenes** - Execute and toggle HomeKit scenes with state tracking
- **Favourites** - Pin frequently used devices and scenes to the top of the menu
- **Multi-home support** - Switch between multiple HomeKit homes
- **Native experience** - Built with AppKit for a true macOS look and feel

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
| Contact sensors | Open/closed state display |
| Temperature & Humidity sensors | Summary display per room |

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

## HomeKit entitlement

This app requires the HomeKit entitlement. You'll need to:

1. Enable HomeKit capability in your Apple Developer account
2. Create an App ID with HomeKit enabled
3. The entitlement is already configured in `Itsyhome/Itsyhome.entitlements`

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- **Website**: [itsyhome.app](https://itsyhome.app)
- **Issues**: [GitHub Issues](https://github.com/nickustinov/itsyhome-macos/issues)

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
