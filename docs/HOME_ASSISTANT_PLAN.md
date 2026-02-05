# Home Assistant integration plan

This document outlines the plan for adding Home Assistant support to Itsyhome, creating a unified app that supports both HomeKit and Home Assistant.

## Executive summary

Home Assistant provides excellent coverage for all 18 device types we currently support via HomeKit. The main work involves:

1. **Platform abstraction layer** - Abstract HomeKit-specific code behind protocols
2. **Home Assistant API client** - REST + WebSocket client for HA communication
3. **Entity mapping** - Map HA domains/entities to our existing UI components
4. **Authentication** - Server URL + long-lived access token management
5. **Testing** - Docker-based testing with HA demo integration

## Device compatibility matrix

| # | Device Type | HomeKit Service | HA Domain | HA Mapping | Extra Work Needed |
|---|-------------|-----------------|-----------|------------|-------------------|
| 1 | **Light** | Lightbulb | `light` | Direct | Color temp: HA uses Kelvin, HK uses Mireds. HA brightness 0-255, HK 0-100 |
| 2 | **Switch** | Switch | `switch` | Direct | None |
| 3 | **Outlet** | Outlet | `switch` | Partial | HA has no native `OutletInUse` - need power sensor lookup |
| 4 | **Thermostat** | Thermostat | `climate` | Direct | Mode mapping: HK numeric → HA strings. `heat_cool` vs `auto` distinction |
| 5 | **AC/Heater-Cooler** | HeaterCooler | `climate` | Direct | Same as thermostat, use `swing_mode` for oscillation |
| 6 | **Lock** | LockMechanism | `lock` | Direct | HA has explicit `locking`/`unlocking` states vs HK target/current diff |
| 7 | **Blinds** | WindowCovering | `cover` | Direct | Position scale matches (0=closed, 100=open). Tilt supported |
| 8 | **Door** | Door | `cover` | Direct | Use `device_class: door` |
| 9 | **Window** | Window | `cover` | Direct | Use `device_class: window` |
| 10 | **Fan** | Fan/FanV2 | `fan` | Direct | Speed: both 0-100%. Direction: HA strings vs HK integers |
| 11 | **Garage Door** | GarageDoorOpener | `cover` | Partial | HA has no built-in obstruction attr - need linked binary_sensor |
| 12 | **Humidifier** | HumidifierDehumidifier | `humidifier` | Partial | HA separates by device_class. No auto mode for combined devices |
| 13 | **Air Purifier** | AirPurifier | `fan` | Custom | HA has no air_purifier domain - map to fan with preset modes |
| 14 | **Valve** | Valve | `valve` | Partial | HA lacks `InUse` dual-state. No duration/remaining time |
| 15 | **Security System** | SecuritySystem | `alarm_control_panel` | Direct | HA has more states (vacation, custom_bypass). Code handling |
| 16 | **Temperature Sensor** | TemperatureSensor | `sensor` | Direct | Filter by `device_class: temperature` |
| 17 | **Humidity Sensor** | HumiditySensor | `sensor` | Direct | Filter by `device_class: humidity` |
| 18 | **Slat** | Slat | `cover` | Partial | Map to cover with tilt. HA has no dedicated slat concept |

### Special devices

| Device | HomeKit | Home Assistant | Notes |
|--------|---------|----------------|-------|
| **Camera** | CameraProfile | `camera` | HLS/MJPEG/WebRTC. WebRTC is lowest latency |
| **Doorbell** | Doorbell service | `event` entity | `device_class: doorbell`, subscribe to press events |
| **Scene** | ActionSet | `scene` | HA scenes are stateless, no reversal. Can't query target values |

## Detailed mapping notes

### 1. Lights

**HomeKit → Home Assistant mapping:**

| HomeKit Characteristic | Home Assistant Attribute | Conversion |
|------------------------|-------------------------|------------|
| `PowerState` | `state` (on/off) | Direct |
| `Brightness` (0-100) | `brightness` (1-255) | `ha = hk * 2.55`, `hk = ha / 2.55` |
| `Hue` (0-360) | `hs_color[0]` (0-360) | Direct |
| `Saturation` (0-100) | `hs_color[1]` (0-100) | Direct |
| `ColorTemperature` (Mireds) | `color_temp_kelvin` | `kelvin = 1000000 / mireds` |

**Services:**
- `light.turn_on` with `brightness`, `hs_color`, `color_temp_kelvin`
- `light.turn_off`
- `light.toggle`

### 2. Climate (Thermostat + AC)

**Mode mapping:**

| HomeKit TargetHeatingCoolingState | Home Assistant hvac_mode |
|-----------------------------------|-------------------------|
| 0 (Off) | `off` |
| 1 (Heat) | `heat` |
| 2 (Cool) | `cool` |
| 3 (Auto) | `heat_cool` (NOT `auto`!) |

**Important:** HA's `auto` means device-controlled (AI/schedule). HA's `heat_cool` means user-set temperature range - this is what HomeKit's "Auto" actually does.

**Temperature thresholds:**

| HomeKit | Home Assistant |
|---------|----------------|
| `HeatingThresholdTemperature` | `target_temp_low` |
| `CoolingThresholdTemperature` | `target_temp_high` |
| `TargetTemperature` | `target_temperature` |

### 3. Covers (Blinds, Garage, Door, Window)

**Position:** Both use 0-100 scale with 0=closed, 100=open. Direct mapping.

**Tilt:**
- HomeKit: `CurrentHorizontalTiltAngle` / `TargetHorizontalTiltAngle` (-90 to 90)
- HA: `current_tilt_position` (0-100)
- Conversion: `ha = (hk + 90) / 1.8`

**Garage door states:**

| HomeKit CurrentDoorState | Home Assistant state |
|--------------------------|---------------------|
| 0 (Open) | `open` |
| 1 (Closed) | `closed` |
| 2 (Opening) | `opening` |
| 3 (Closing) | `closing` |
| 4 (Stopped) | N/A (HA doesn't have stopped) |

**Obstruction detection:** HA has no built-in attribute. Need to find associated `binary_sensor` with `device_class: safety`.

### 4. Locks

**State mapping:**

| HomeKit LockCurrentState | Home Assistant state |
|--------------------------|---------------------|
| 0 (Unsecured) | `unlocked` |
| 1 (Secured) | `locked` |
| 2 (Jammed) | `jammed` |
| 3 (Unknown) | `unknown` / unavailable |

**Transitional states:** HA has explicit `locking`, `unlocking`, `opening` states. HomeKit infers from target vs current mismatch.

### 5. Fans

| HomeKit | Home Assistant | Conversion |
|---------|----------------|------------|
| `Active` (0/1) | `state` (on/off) | Direct |
| `RotationSpeed` (0-100) | `percentage` (0-100) | Direct |
| `RotationDirection` (0=CW, 1=CCW) | `direction` ("forward"/"reverse") | 0→"forward", 1→"reverse" |
| `SwingMode` (0/1) | `oscillating` (bool) | Direct |
| `TargetFanState` (0=manual, 1=auto) | `preset_mode` | 1→"auto" preset if available |

### 6. Humidifier/Dehumidifier

**Key difference:** HomeKit has unified HumidifierDehumidifier with mode switching. HA separates by `device_class`.

| HomeKit TargetState | Home Assistant |
|--------------------|----------------|
| 0 (Auto) | No direct equivalent |
| 1 (Humidifier) | `device_class: humidifier` |
| 2 (Dehumidifier) | `device_class: dehumidifier` |

**Thresholds:**
- HomeKit has separate `RelativeHumidityHumidifierThreshold` and `RelativeHumidityDehumidifierThreshold`
- HA has single `target_humidity`

### 7. Security System

| HomeKit State | Home Assistant state |
|---------------|---------------------|
| 0 (Stay Arm) | `armed_home` |
| 1 (Away Arm) | `armed_away` |
| 2 (Night Arm) | `armed_night` |
| 3 (Disarmed) | `disarmed` |
| 4 (Triggered) | `triggered` |

**Extra HA states not in HomeKit:**
- `armed_vacation` → map to `armed_away`
- `armed_custom_bypass` → map to `armed_home`
- `arming` → infer from target vs current
- `pending` → show as transitional

### 8. Cameras

**Streaming options (preference order for latency):**

1. **WebRTC** (0.5s latency) - Best but complex
   - Use `camera/webrtc/offer` WebSocket command
   - Requires RTCPeerConnection in native code

2. **HLS** (5-30s latency) - Easiest with AVPlayer
   - Use `camera/stream` WebSocket command
   - Returns `/api/hls/{token}/playlist.m3u8`

3. **MJPEG** (1-3s latency) - Simple HTTP stream
   - `GET /api/camera_proxy_stream/{entity_id}`
   - Parse multipart/x-mixed-replace

**Snapshots:**
- `GET /api/camera_proxy/{entity_id}`

**Recommendation:** Start with HLS for simplicity, add WebRTC later for low-latency option.

### 9. Doorbells

**No separate domain.** Doorbells use:
- `event` entity with `device_class: doorbell`
- Events: `press`, `single_press`, `double_press`, `hold`

**Implementation:**
1. Subscribe to `state_changed` events
2. Filter for `event.*` entities with doorbell device_class
3. Watch for state changes indicating button press
4. Trigger camera panel display (same as HomeKit doorbell flow)

### 10. Scenes

| Feature | HomeKit | Home Assistant |
|---------|---------|----------------|
| Activation | `executeActionSet()` | `scene.turn_on` service |
| Deactivation | No native support | No native support |
| Query contents | Can enumerate actions | Limited - entity list only, not values |
| State tracking | Stateless | Stateless |

**Our existing scene state tracking** (comparing current values to scene targets) won't work well with HA since we can't query target values through the public API.

**Options:**
1. Disable scene state tracking for HA
2. Use undocumented `/api/config/scene/config/[ID]` endpoint
3. Store scene definitions locally after first activation

## Architecture

### Platform abstraction

Create a protocol-based abstraction layer:

```
┌─────────────────────────────────────────────────────────┐
│                    macOSBridge                          │
│  (MenuBuilder, MenuItems, ActionEngine - unchanged)     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│               SmartHomePlatform Protocol                │
│  - fetchData() -> MenuData                              │
│  - executeScene(id)                                     │
│  - readCharacteristic(id) -> Any                        │
│  - writeCharacteristic(id, value)                       │
│  - subscribeToUpdates(callback)                         │
│  - openCameraStream(id) -> URL                          │
└─────────────────────────────────────────────────────────┘
           │                              │
           ▼                              ▼
┌─────────────────────┐      ┌─────────────────────┐
│  HomeKitPlatform    │      │ HomeAssistantPlatform│
│  (existing code)    │      │    (new)            │
└─────────────────────┘      └─────────────────────┘
```

### Key components to create

1. **`SmartHomePlatform` protocol** - Abstract interface for platform operations
2. **`HomeAssistantClient`** - REST + WebSocket API client
3. **`HomeAssistantPlatform`** - Implements SmartHomePlatform for HA
4. **`EntityMapper`** - Maps HA entities to our ServiceData model
5. **`HAAuthenticationManager`** - Server URL + token storage

### Data flow

```
Home Assistant                    Itsyhome
─────────────                    ─────────
WebSocket ──state_changed──► HAClient ──► EntityMapper ──► MenuData
                                                              │
                                                              ▼
REST API ◄──call_service─── ActionEngine ◄── MenuItems ◄── Menu
```

### File structure (new files)

```
Itsyhome/
├── HomeAssistant/
│   ├── HomeAssistantClient.swift       # REST + WebSocket client
│   ├── HomeAssistantPlatform.swift     # SmartHomePlatform implementation
│   ├── EntityMapper.swift              # Entity → ServiceData mapping
│   ├── HAModels.swift                  # Codable models for HA API
│   └── HAAuthManager.swift             # Credentials storage
├── Shared/
│   ├── SmartHomePlatform.swift         # Platform abstraction protocol
│   └── BridgeProtocols.swift           # (existing, unchanged)
└── iOS/
    ├── HomeKitPlatform.swift           # Refactored from HomeKitManager
    └── HomeKitManager.swift            # (existing, delegates to platform)
```

## Testing strategy

### Local Docker setup

```bash
# Run Home Assistant with demo integration
docker run -d \
  --name homeassistant-dev \
  -p 8123:8123 \
  -v $(pwd)/ha-test-config:/config \
  ghcr.io/home-assistant/home-assistant:stable
```

**ha-test-config/configuration.yaml:**
```yaml
homeassistant:
  name: Test Home
  unit_system: metric

demo:

# Enable API
api:

# Enable WebSocket
websocket_api:
```

This provides 30+ demo entities across all device types.

### Test coverage needed

1. **Unit tests** for EntityMapper (HA → ServiceData conversion)
2. **Unit tests** for characteristic value conversions (brightness, color temp, etc.)
3. **Integration tests** with mock HA WebSocket server
4. **Manual testing** with Docker demo instance

### Mock server for CI

Create a lightweight mock that:
- Accepts WebSocket connections
- Returns canned state data
- Responds to service calls
- Emits state_changed events

## Implementation phases

### Phase 1: Foundation
- [ ] Create `SmartHomePlatform` protocol
- [ ] Refactor `HomeKitManager` to implement protocol
- [ ] Create `HomeAssistantClient` (REST + WebSocket)
- [ ] Create `HAAuthManager` (server URL + token storage)
- [ ] Add settings UI for HA connection

### Phase 2: Core devices
- [ ] Implement `EntityMapper` for lights, switches
- [ ] Implement climate (thermostat/AC) mapping
- [ ] Implement cover (blinds/garage) mapping
- [ ] Implement lock mapping
- [ ] Implement fan mapping

### Phase 3: Remaining devices
- [ ] Implement sensor mapping (temp, humidity)
- [ ] Implement humidifier mapping
- [ ] Implement valve mapping
- [ ] Implement security system mapping
- [ ] Implement air purifier (as fan) mapping

### Phase 4: Cameras & doorbells
- [ ] Implement camera streaming (HLS first)
- [ ] Implement snapshot fetching
- [ ] Implement doorbell event subscription
- [ ] Wire up doorbell → camera panel flow

### Phase 5: Scenes & polish
- [ ] Implement scene activation
- [ ] Handle areas → rooms mapping
- [ ] Test with real HA instance
- [ ] Performance optimization

## Open questions (resolved)

1. **Scene state tracking** - HA doesn't expose target values via public API. **Decision:** No state tracking for HA scenes - just "click to activate" without on/off toggle. Scenes appear as action items, not toggleable switches.

2. **Camera streaming** - **Decision:** Use WebRTC for low latency. macOS has native WebRTC libraries available.

3. **Multi-home** - HA has no multi-home concept. **Decision:** Don't show Home picker menu for HA connections. One HA instance = one "home".

4. **Air purifier** - **Decision:** Yes, map to fan domain with preset modes.

5. **Outlet in-use** - **Decision:** Drop "in use" indicator for HA outlets. Not worth the complexity of finding associated power sensors.

## First-launch UX

**Platform picker on first launch:**
```
┌─────────────────────────────────┐
│  Welcome to Itsyhome            │
│                                 │
│  Choose your smart home:        │
│                                 │
│  [🏠 Apple HomeKit]             │
│  [🔵 Home Assistant]            │
│                                 │
│  (You can add more later)       │
└─────────────────────────────────┘
```

- Only requests HomeKit permission if user picks HomeKit
- HA users skip HomeKit permission entirely
- Settings allows adding the other platform later
- Clean mental model, respects user's actual setup

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| HA API changes | Breaking changes | Pin to stable API, use versioned endpoints |
| WebSocket disconnects | Lost real-time updates | Robust reconnection with exponential backoff |
| Camera latency | Poor UX | Start with HLS, add WebRTC option |
| Entity discovery | Missing devices | Use registry APIs, handle unknown entities gracefully |
| No HA for testing | Slow development | Docker demo + comprehensive mocks |

## Resources

- [Home Assistant REST API](https://developers.home-assistant.io/docs/api/rest/)
- [Home Assistant WebSocket API](https://developers.home-assistant.io/docs/api/websocket/)
- [Home Assistant Demo Integration](https://www.home-assistant.io/integrations/demo/)
- [Entity Developer Docs](https://developers.home-assistant.io/docs/core/entity/)
