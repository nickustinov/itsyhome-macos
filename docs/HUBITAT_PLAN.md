# Hubitat integration plan

This document describes the Hubitat Elevation support in Itsyhome, creating a unified app that supports HomeKit, Home Assistant, and Hubitat. This is retrospective documentation of a completed implementation.

## Executive summary

Hubitat Elevation provides coverage for 14 of the 18 device types we support via HomeKit, plus temperature and humidity sensors. The main work involved:

1. **Platform abstraction layer** - Hubitat implements the same `SmartHomePlatform` protocol as HomeKit and Home Assistant
2. **Maker API client** - REST client for device enumeration and commands, plus EventSocket WebSocket for real-time updates
3. **Capability mapping** - Map Hubitat capabilities/attributes to our existing ServiceData model (vs. HA's domain-based model)
4. **Authentication** - Hub URL + Maker API App ID + access token management
5. **Device mapper** - Hubitat uses a capability-based model (devices have multiple capabilities) rather than HA's domain-based model (one entity = one domain), requiring priority-based capability resolution

## Device compatibility matrix

| # | Device Type | HomeKit Service | Hubitat Capability | Mapping | Extra Work Needed |
|---|-------------|-----------------|-------------------|---------|-------------------|
| 1 | **Light** | Lightbulb | `ColorControl` / `ColorTemperature` / `SwitchLevel` | Direct | Hue: Hubitat 0-100, HK 0-360. Color temp: Hubitat Kelvin, HK Mireds. Brightness 0-100 on both sides |
| 2 | **Switch** | Switch | `Switch` | Direct | None |
| 3 | **Outlet** | Outlet | `Switch` (device type contains "outlet"/"plug") | Partial | No native outlet capability - inferred from device type name. No OutletInUse |
| 4 | **Thermostat** | Thermostat | `Thermostat` / `ThermostatMode` | Direct | Mode-aware setpoint commands. Temperature unit detection (F/C). `thermostatSetpoint` vs `heatingSetpoint` fallback |
| 5 | **AC/Heater-Cooler** | HeaterCooler | N/A | N/A | Not implemented - Hubitat thermostats map to Thermostat service type only |
| 6 | **Lock** | LockMechanism | `Lock` | Direct | Hubitat has `locked`/`unlocked` strings vs HK integer states |
| 7 | **Blinds** | WindowCovering | `WindowShade` / `WindowBlind` | Direct | Position 0-100 on both sides. Stop command via `setPosition(-1)` -> `stopPositionChange` |
| 8 | **Door** | Door | N/A | N/A | No dedicated door capability in Hubitat; covered by `WindowShade` if applicable |
| 9 | **Window** | Window | N/A | N/A | No dedicated window capability in Hubitat; covered by `WindowShade` if applicable |
| 10 | **Fan** | FanV2 | `FanControl` / `Fan` | Direct | Hubitat reports speed as string names ("low", "medium", etc.) - requires string-to-percentage mapping table |
| 11 | **Garage Door** | GarageDoorOpener | `GarageDoorControl` | Direct | Door state string-to-integer mapping. No obstruction detection |
| 12 | **Humidifier** | HumidifierDehumidifier | N/A | N/A | Not implemented - no standard Hubitat capability for this |
| 13 | **Air Purifier** | AirPurifier | N/A | N/A | Not implemented - no Hubitat equivalent |
| 14 | **Valve** | Valve | `Valve` | Direct | Hubitat "open"/"close" strings map to HK Active/InUse integers |
| 15 | **Security System** | SecuritySystem | HSM (Hubitat Safety Monitor) | Partial | HSM is a hub-level feature, not a device capability. Uses separate `/hsm` API endpoint |
| 16 | **Temperature Sensor** | TemperatureSensor | `TemperatureMeasurement` | Direct | Temperature unit normalization (F->C for internal storage) |
| 17 | **Humidity Sensor** | HumiditySensor | `RelativeHumidityMeasurement` | Direct | Direct 0-100% mapping |
| 18 | **Slat** | Slat | N/A | N/A | No Hubitat equivalent |

### Special devices

| Device | HomeKit | Hubitat | Notes |
|--------|---------|---------|-------|
| **Camera** | CameraProfile | N/A | Hubitat Maker API has no camera streaming support. `hasCameras` returns `false` |
| **Doorbell** | Doorbell service | N/A | No doorbell event support in Maker API |
| **Scene** | ActionSet | N/A | Maker API does not expose scenes. `executeScene` logs a warning and returns |

## Detailed mapping notes

### 1. Lights

**Capability priority:** `ColorControl` > `ColorTemperature` > `SwitchLevel` -- any of these maps to Lightbulb service type.

**Itsyhome <-> Hubitat attribute mapping:**

| Itsyhome Characteristic | Hubitat Attribute | Conversion |
|------------------------|-------------------|------------|
| `power` (Bool) | `switch` ("on"/"off") | `"on" -> true`, `"off" -> false` |
| `brightness` (0-100) | `level` (0-100) | Direct (no conversion) |
| `hue` (0-360) | `hue` (0-100) | Read: `itsyhome = hubitat * 360 / 100`. Write: `hubitat = itsyhome * 100 / 360` |
| `saturation` (0-100) | `saturation` (0-100) | Direct (no conversion) |
| `color_temp` (Mireds) | `colorTemperature` (Kelvin) | Read: `mireds = 1000000 / kelvin`. Write: `kelvin = 1000000 / mireds` |

**Color temperature range:** Min 153 mireds (6500K), Max 500 mireds (2000K) -- hardcoded defaults for all color-capable lights.

**Commands:**
- `on` / `off` -- power control
- `setLevel` with value `0-100` -- brightness
- `setHue` with value `0-100` -- hue (after conversion from 0-360)
- `setSaturation` with value `0-100` -- saturation
- `setColorTemperature` with value in Kelvin -- color temperature (after conversion from mireds)

### 2. Switches and Outlets

**Itsyhome <-> Hubitat attribute mapping:**

| Itsyhome Characteristic | Hubitat Attribute | Conversion |
|------------------------|-------------------|------------|
| `power` (Bool) | `switch` ("on"/"off") | `"on" -> true`, `"off" -> false` |

**Outlet detection:** A `Switch` capability device is classified as an Outlet (instead of Switch) if the device `type` string (lowercased) contains "outlet" or "plug".

**Commands:**
- `on` / `off`

### 3. Climate (Thermostat)

**Mode mapping:**

| Itsyhome hvac_mode (Int) | Hubitat thermostatMode (String) |
|--------------------------|--------------------------------|
| 0 (Off) | `off` |
| 1 (Heat) | `heat` |
| 2 (Cool) | `cool` |
| 3 (Auto) | `auto` |

**Note:** Hubitat uses `auto` for what HomeKit calls "Auto" (user-set temperature range). This differs from Home Assistant which distinguishes `auto` (device-controlled) from `heat_cool` (user-set range). Hubitat also supports `emergency heat` which maps to 3 (Auto) on read.

**Operating state mapping:**

| Itsyhome hvac_action (Int) | Hubitat thermostatOperatingState (String) |
|---------------------------|------------------------------------------|
| 0 (Idle) | `idle` |
| 1 (Heating) | `heating` |
| 2 (Cooling) | `cooling` |

**Temperature mapping:**

| Itsyhome Characteristic | Hubitat Attribute | Notes |
|------------------------|-------------------|-------|
| `current_temp` | `temperature` | Normalized to Celsius internally |
| `target_temp` | `thermostatSetpoint` (preferred), `heatingSetpoint` (fallback) | Normalized to Celsius internally |
| `target_temp_high` | `coolingSetpoint` | Normalized to Celsius internally |
| `target_temp_low` | `heatingSetpoint` | Normalized to Celsius internally |
| `hvac_mode` | `thermostatMode` | String-to-int mapping (see above) |
| `hvac_action` | `thermostatOperatingState` | String-to-int mapping (see above) |

**Temperature unit handling:**
- Hubitat hubs default to Fahrenheit
- Unit is auto-detected from device `temperatureScale` attribute (looks for "C" or "F")
- All temperatures are normalized to Celsius for internal storage via `normalizeTemperature()`
- Temperatures are converted back to hub-native units via `denormalizeTemperature()` before sending commands

**Mode-aware setpoint commands:**
- When writing `target_temp`, the current thermostat mode determines which command to send:
  - Mode `cool` -> `setCoolingSetpoint`
  - Mode `heat` or `emergency heat` -> `setHeatingSetpoint`
  - Default -> `setHeatingSetpoint`
- Writing `target_temp_high` always sends `setCoolingSetpoint`
- Writing `target_temp_low` always sends `setHeatingSetpoint`

**Commands:**
- `setThermostatMode` with mode string
- `setHeatingSetpoint` with temperature in hub-native units
- `setCoolingSetpoint` with temperature in hub-native units

### 4. Locks

**State mapping:**

| Itsyhome lock_state (Int) | Hubitat lock (String) |
|--------------------------|----------------------|
| 0 (Unsecured) | `unlocked` |
| 1 (Secured) | `locked` |
| 3 (Unknown) | Any other value |

**Note:** Hubitat does not report a separate `jammed` state (mapped to unknown). The `lock_target` characteristic is set to the same value as `lock_state` since Hubitat has no separate target state attribute.

**Commands:**
- `lock` -- when target state is 1 (Secured)
- `unlock` -- when target state is 0 (Unsecured)

### 5. Covers (Blinds / Window Coverings)

**Capabilities:** `WindowShade` or `WindowBlind`

| Itsyhome Characteristic | Hubitat Attribute | Conversion |
|------------------------|-------------------|------------|
| `position` (0-100) | `position` (0-100) | Direct |
| `target_position` (0-100) | N/A (command only) | Direct |

**Stop command:** Writing `target_position = -1` sends the `stopPositionChange` command instead of `setPosition`.

**Commands:**
- `setPosition` with value `0-100`
- `stopPositionChange` -- triggered by target position of -1

**Note:** No tilt support is implemented for Hubitat covers. Hubitat's `WindowBlind` capability does support tilt but it is not mapped.

### 6. Garage Doors

**State mapping:**

| Itsyhome door_state (Int) | Hubitat door (String) |
|--------------------------|----------------------|
| 0 (Open) | `open` |
| 1 (Closed) | `closed` |
| 2 (Opening) | `opening` |
| 3 (Closing) | `closing` |
| 4 (Stopped) | Any other value |

**Target door mapping:** `target_door` is derived from current state: 0 (open target) if door is `"open"`, 1 (close target) otherwise.

**Commands:**
- `open` -- when target door is 0
- `close` -- when target door is 1

**Note:** No obstruction detection. Hubitat `GarageDoorControl` does not expose an obstruction attribute.

### 7. Fans

**Capability priority:** `FanControl` or `Fan` capability maps to FanV2 service type.

| Itsyhome Characteristic | Hubitat Attribute | Conversion |
|------------------------|-------------------|------------|
| `power` (Bool) | `switch` ("on"/"off") | `"on" -> true`, `"off" -> false` |
| `speed` (0-100%) | `speed` (string name) | String-to-percentage mapping table (see below) |

**Fan speed string-to-percentage mapping (read):**

| Hubitat Speed String | Itsyhome Percentage |
|---------------------|-------------------|
| `off` | 0 |
| `low` | 20 |
| `medium-low` | 40 |
| `medium` | 60 |
| `medium-high` | 80 |
| `high` | 100 |
| `on` | 50 |
| `auto` | 50 |

**Fan speed percentage-to-string mapping (write):**

| Itsyhome Percentage | Hubitat Command |
|-------------------|-----------------|
| 0 | `off` (power off command, not setSpeed) |
| 1-20 | `setSpeed "low"` |
| 21-40 | `setSpeed "medium-low"` |
| 41-60 | `setSpeed "medium"` |
| 61-80 | `setSpeed "medium-high"` |
| 81-100 | `setSpeed "high"` |

**Fallback:** If no `speed` string attribute is present, falls back to reading the `level` attribute (from `SwitchLevel` capability) as a direct percentage.

### 8. Valves

| Itsyhome Characteristic | Hubitat Attribute | Conversion |
|------------------------|-------------------|------------|
| `active` (Int 0/1) | `valve` ("open"/"close") | `"open" -> 1`, `"close" -> 0` |
| `valve_state` (Int 0/1) | `valve` ("open"/"close") | `"open" -> 1`, `"close" -> 0` |

**Commands:**
- `open` -- when active/valve_state is set to 1 (true)
- `close` -- when active/valve_state is set to 0 (false)

### 9. Security System (HSM)

**Note:** Hubitat Safety Monitor (HSM) is a hub-level feature accessed via the `/hsm` Maker API endpoint, not a device capability. HSM status is read with `GET /hsm` and set with `GET /hsm/{command}`.

**State mapping (write only -- implemented in action dispatch):**

| Itsyhome alarm_target (Int) | Hubitat HSM Command |
|----------------------------|---------------------|
| 0 (Stay Arm) | `armHome` |
| 1 (Away Arm) | `armAway` |
| 2 (Night Arm) | `armNight` |
| 3 (Disarmed) | `disarm` |

**HSM model:** The `HubitatHSMStatus` model parses the `hsm` field from the API response.

### 10. Temperature Sensors

| Itsyhome Characteristic | Hubitat Attribute | Conversion |
|------------------------|-------------------|------------|
| `current_temp` | `temperature` | Normalized to Celsius via `normalizeTemperature()` |

**Capability:** `TemperatureMeasurement`. Devices with this capability (but no higher-priority capability like Thermostat) are mapped to TemperatureSensor service type.

### 11. Humidity Sensors

| Itsyhome Characteristic | Hubitat Attribute | Conversion |
|------------------------|-------------------|------------|
| `humidity` (0-100) | `humidity` (0-100) | Direct (no conversion) |

**Capability:** `RelativeHumidityMeasurement`. Mapped to HumiditySensor service type.

### 12. Cameras, Doorbells, and Scenes

**Not supported.** Hubitat's Maker API does not expose:
- Camera streaming or snapshot endpoints
- Doorbell press events
- Scene definitions or activation

`hasCameras` returns `false`. `executeScene()` logs a warning. The `MenuData` returned has empty `scenes` and `cameras` arrays.

## Architecture

### Platform abstraction

```
+-----------------------------------------------------------+
|                    macOSBridge                              |
|  (MenuBuilder, MenuItems, ActionEngine - unchanged)        |
+-----------------------------------------------------------+
                           |
                           v
+-----------------------------------------------------------+
|               SmartHomePlatform Protocol                    |
|  - connect() / disconnect()                                |
|  - loadAllData() -> MenuData                               |
|  - executeScene(id)                                        |
|  - readCharacteristic(id) -> Any                           |
|  - writeCharacteristic(id, value)                          |
|  - getCameraStream(id) -> CameraStreamInfo                 |
+-----------------------------------------------------------+
        |                   |                   |
        v                   v                   v
+----------------+  +------------------+  +------------------+
| HomeKitPlatform|  | HomeAssistant    |  | HubitatPlatform  |
| (existing)     |  | Platform         |  | (new)            |
+----------------+  +------------------+  +------------------+
```

### Key components

1. **`HubitatPlatform`** (`HubitatPlatform.swift`) - Implements `SmartHomePlatform` protocol. Manages connection lifecycle, data loading, and menu data generation.
2. **`HubitatClient`** (`HubitatClient.swift`) - REST + EventSocket WebSocket client. Handles all HTTP requests to Maker API and WebSocket event streaming.
3. **`HubitatDeviceMapper`** (`HubitatDeviceMapper.swift`) - Maps Hubitat devices (capabilities + attributes) to Itsyhome's `ServiceData` model. Manages mutable attribute state, characteristic UUID generation, and value conversions.
4. **`HubitatModels`** (`HubitatModels.swift`) - Codable models for Maker API responses: `HubitatDevice`, `HubitatDeviceSummary`, `HubitatEvent`, `HubitatCommand`, `HubitatHSMStatus`, `HubitatMode`.
5. **`HubitatAuthManager`** (`HubitatAuthManager.swift`) - Singleton credential storage (hub URL, app ID, access token).
6. **`HubitatBridge`** (`HubitatBridge.swift`) - Adapts `HubitatPlatform` to the `Mac2iOS` protocol expected by menu items and action engine.

### Data flow

```
Hubitat Hub                          Itsyhome
------------                         --------
EventSocket --device event--> HubitatClient --> HubitatDeviceMapper --> platformDidUpdateCharacteristic
  (ws://.../eventsocket)                           (update attr)              |
                                                                             v
REST API <--GET /devices/{id}/{cmd}-- HubitatPlatform <-- ActionEngine <-- Menu
  (/apps/api/{appId}/...)
```

### File structure

```
Itsyhome/
  Hubitat/
    HubitatModels.swift              # Codable models for Maker API
    HubitatClient.swift              # REST + EventSocket WebSocket client
    HubitatDeviceMapper.swift        # Capability -> ServiceData mapping
    HubitatPlatform.swift            # SmartHomePlatform implementation
    HubitatPlatform+Actions.swift    # Command dispatch, value conversions for writes
    HubitatPlatform+Delegate.swift   # HubitatClientDelegate (event handling)
    HubitatAuthManager.swift         # Credential management (singleton)

macOSBridge/
  Hubitat/
    HubitatBridge.swift              # Mac2iOS adapter for Hubitat
  PlatformPicker/
    HubitatConnectWindowController.swift  # Onboarding UI (3-field form)
  MacOSController.swift              # Integration wiring (connect/disconnect, delegates)
```

## Room support

Rooms are derived from the Maker API `/devices/all` response. Each device JSON object includes `room` (string name) and `roomId` (integer ID) fields when the device is assigned to a room in the Hubitat hub.

**Implementation details:**
- `HubitatDevice` parses `roomId` (Int or String, 0/null = unassigned) and `room` (String name)
- `HubitatDeviceMapper.generateRooms()` collects unique `roomId -> roomName` pairs from all devices
- Room UUIDs are deterministic: `SHA256("hubitat_room_{roomId}")` with version-4 UUID bits set
- Devices with no room assignment (`roomId` is nil) have `roomIdentifier = nil` in their `AccessoryData`
- There is no separate rooms endpoint -- rooms are inferred entirely from device data

**Key difference from Home Assistant:** HA has explicit area and floor registries. Hubitat embeds room assignment directly on each device in the Maker API response.

## Real-time updates

### EventSocket WebSocket

Hubitat provides a global WebSocket at `ws://{hub_ip}/eventsocket` that streams all device and location events. This is a hub-level endpoint (not Maker API-specific) and requires no authentication.

**Connection flow:**
1. REST: `GET /apps/api/{appId}/devices/all` -- loads all devices, populates `authorizedDeviceIds`
2. WebSocket: Connect to `ws://{hub_ip}/eventsocket`
3. EventSocket has no authentication handshake -- connection is open immediately
4. Start receiving messages and filtering by authorized device IDs

**Event filtering:**
- `DEVICE` events: Only forwarded if `deviceId` is in the `authorizedDeviceIds` set (populated from Maker API device list)
- `LOCATION` events (HSM, mode changes): Forwarded unconditionally
- This filtering is important because EventSocket emits events for ALL hub devices, not just those authorized in Maker API

**Event handling:**
1. `HubitatClient` receives WebSocket message, parses as `HubitatEvent`
2. Filters by `authorizedDeviceIds`
3. Forwards to `HubitatPlatform` via `HubitatClientDelegate`
4. `HubitatPlatform` calls `mapper.updateDeviceAttribute()` to update mutable state
5. Re-generates all characteristic values for the device
6. Fires `platformDidUpdateCharacteristic` for each changed value

**Reconnection:**
- Exponential backoff: base 1s, doubles each attempt, capped at 30s, with random jitter (0-1s)
- Max 10 reconnection attempts
- Ping every 30 seconds to detect stale connections
- System wake and network availability changes trigger reconnection via `MacOSController`

## Authentication and credentials

### Three-field credential model

| Credential | Storage | Key/Account |
|-----------|---------|-------------|
| Hub URL | `UserDefaults` | `HubitatHubURL` |
| Maker API App ID | `UserDefaults` | `HubitatAppId` |
| Access Token | macOS Keychain | Service: `com.nickustinov.itsyhome.hubitat`, Account: `access_token` |

**Why Keychain for the token:** The access token grants full control of authorized devices. Keychain provides encryption at rest and per-app isolation. Hub URL and App ID are not sensitive.

**Keychain access:** `kSecAttrAccessibleAfterFirstUnlock` -- token is available after first unlock, even if device is locked (important for menu bar app running at login).

### Validation

`HubitatAuthManager.validateAndFetchDeviceCount()` tests credentials by calling `GET /apps/api/{appId}/devices?access_token={token}`. Returns device count on success, throws `HubitatAuthError` on failure.

### URL construction

All REST API calls go through `HubitatClient.makeURL(endpoint:)`:
```
http://{hub_ip}/apps/api/{appId}/{endpoint}?access_token={token}
```

Command URLs use path-based parameters:
```
http://{hub_ip}/apps/api/{appId}/devices/{deviceId}/{command}/{value}?access_token={token}
```

Multi-value parameters are comma-joined in the path.

## Testing strategy

### Testing with a real hub

The primary testing approach uses a physical Hubitat Elevation hub:

1. Install Maker API app on the hub (Apps > Add Built-In App > Maker API)
2. Select devices to expose
3. Copy Hub URL, App ID, and Access Token
4. Enter credentials in Itsyhome's Hubitat connect screen

### Test coverage areas

1. **Capability mapping** - Verify correct service type resolution with priority ordering (ColorControl > ColorTemperature > SwitchLevel > Thermostat > Lock > etc.)
2. **Value conversions** - Hue (0-100 <-> 0-360), color temp (Kelvin <-> Mireds), temperature (F/C <-> Celsius), fan speed (strings <-> percentages)
3. **EventSocket** - Verify event filtering, reconnection behavior, attribute state updates
4. **Credential validation** - Test with invalid URLs, wrong App IDs, expired tokens
5. **Edge cases** - Devices with multiple capabilities, null/empty attribute values, roomId as Int vs String

### No Docker equivalent

Unlike Home Assistant which has a demo mode in Docker, Hubitat requires physical hub hardware. There is no simulator or mock hub available from the vendor.

## Implementation phases

### Phase 1: Foundation
- [x] Implement `HubitatClient` (REST + EventSocket WebSocket)
- [x] Implement `HubitatAuthManager` (hub URL + app ID + token storage)
- [x] Implement `HubitatModels` (device, event, command, HSM, mode models)
- [x] Add Hubitat option to platform picker

### Phase 2: Core devices
- [x] Implement `HubitatDeviceMapper` for lights (with hue, saturation, color temp conversions)
- [x] Implement switch and outlet mapping (outlet detection by device type name)
- [x] Implement thermostat mapping (mode-aware setpoints, temperature unit detection)
- [x] Implement lock mapping
- [x] Implement cover / window covering mapping

### Phase 3: Remaining devices
- [x] Implement fan mapping (speed string-to-percentage table)
- [x] Implement garage door mapping
- [x] Implement valve mapping
- [x] Implement temperature sensor mapping
- [x] Implement humidity sensor mapping
- [x] Implement HSM (security system) command dispatch

### Phase 4: Real-time updates
- [x] Implement EventSocket WebSocket connection
- [x] Implement event filtering by `authorizedDeviceIds`
- [x] Implement reconnection with exponential backoff
- [x] Implement ping keepalive (30s interval)
- [x] Wire up system wake and network change reconnection

### Phase 5: Integration and polish
- [x] Implement `HubitatBridge` (Mac2iOS adapter)
- [x] Wire into `MacOSController` (connect/disconnect, platform switching)
- [x] Implement `HubitatConnectWindowController` (onboarding UI)
- [x] Implement room generation from device data
- [x] Implement deterministic UUID generation (SHA-256 based)

## Open questions (resolved)

1. **No camera support** - Hubitat Maker API has no camera streaming or snapshot endpoints. **Decision:** `hasCameras` returns `false`, camera methods throw/return nil. Users needing cameras should use HomeKit or Home Assistant.

2. **No scene support** - Maker API does not expose hub scenes or rules. **Decision:** `executeScene()` logs a warning. Scenes array is empty in MenuData. No scene UI shown for Hubitat.

3. **Room discovery** - Hubitat has no dedicated rooms API endpoint. **Decision:** Rooms are derived from the `room` and `roomId` fields on each device in the `/devices/all` response. This works well -- every device with a room assignment contributes to the room list.

4. **Fan speed string mapping** - Hubitat `FanControl` capability reports speed as named strings ("low", "medium", "high") rather than percentages. **Decision:** Implemented a bidirectional string-to-percentage mapping table. Fallback to `level` attribute if no speed string is present.

5. **Thermostat mode-aware setpoints** - Hubitat requires using the correct setpoint command (`setHeatingSetpoint` vs `setCoolingSetpoint`) based on the current mode. **Decision:** `writeValueToDevice` checks `getCurrentThermostatMode()` when writing `target_temp` and dispatches to the appropriate command. Direct writes to `target_temp_high`/`target_temp_low` always use `setCoolingSetpoint`/`setHeatingSetpoint` respectively.

6. **EventSocket for real-time updates** - Hubitat's EventSocket is a hub-wide, unauthenticated WebSocket. **Decision:** Filter events by `authorizedDeviceIds` (populated from Maker API device list) to only process events for devices the user has authorized in Maker API.

7. **Temperature unit detection** - Hubitat hubs can be configured for Fahrenheit or Celsius. **Decision:** Auto-detect from `temperatureScale` attribute on any thermostat or temperature sensor device. Default to Fahrenheit if not found (most common for Hubitat users).

8. **Capability priority** - Devices can have multiple capabilities (e.g., a smart bulb with Switch + SwitchLevel + ColorControl). **Decision:** Fixed priority order: ColorControl > ColorTemperature > SwitchLevel > Thermostat/ThermostatMode > Lock > WindowShade/WindowBlind > GarageDoorControl > Valve > FanControl/Fan > Switch > TemperatureMeasurement > RelativeHumidityMeasurement. First match wins.

9. **Multi-home** - Hubitat has no multi-home concept (one hub = one home). **Decision:** `availableHomes` returns empty array. No home picker shown. `HubitatBridge` returns a single virtual home entry for compatibility.

10. **Device ID type inconsistency** - Hubitat API returns `id` and `roomId` as either Int or String depending on context. **Decision:** Normalize all IDs to String at parse time in `HubitatDevice` and `HubitatEvent` models.

## First-launch UX

**Platform picker on first launch (3 options):**
```
+-----------------------------------+
|  Welcome to Itsyhome              |
|                                   |
|  Choose your smart home:          |
|                                   |
|  [ Apple HomeKit    ]             |
|  [ Home Assistant   ]             |
|  [ Hubitat Elevation]             |
|                                   |
|  (You can add more later)         |
+-----------------------------------+
```

**Hubitat connect screen (3 fields):**
```
+-----------------------------------+
|  [Hubitat icon]                   |
|  Connect to Hubitat               |
|                                   |
|  Hub URL                          |
|  [http://192.168.1.xxx         ]  |
|                                   |
|  Maker API App ID                 |
|  [e.g., 42                     ]  |
|                                   |
|  Access token                     |
|  [****************************]   |
|                                   |
|  Configure Maker API in your      |
|  Hubitat hub under Apps >         |
|  Maker API                        |
|                                   |
|  [Back]              [Connect]    |
+-----------------------------------+
```

**Flow:**
1. User selects "Hubitat Elevation" from platform picker
2. Hubitat connect screen appears with 3 fields
3. User enters hub URL, App ID, and access token (from Maker API app page)
4. "Connect" validates credentials via `validateAndFetchDeviceCount()`
5. On success: saves credentials, selects Hubitat platform, restarts app
6. On failure: shows error message, clears credentials
7. "Back" returns to platform picker

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| EventSocket disconnects | Lost real-time updates | Exponential backoff reconnection (max 10 attempts), 30s ping keepalive, system wake/network change triggers |
| Maker API rate limits | Throttled device commands | Commands are individual REST GETs; no batching needed. Low risk for normal usage |
| Hub firmware changes | API breakage | Maker API is a stable, built-in app. EventSocket format is simple JSON. Low churn |
| LAN-only access | No remote control | Hubitat hubs are LAN-only by default. Users must be on the same network (or use VPN). Cloud relay not supported |
| Device ID type inconsistency | Parse failures | All IDs normalized to String at parse time. Handles both Int and String JSON types |
| Multiple capabilities on one device | Wrong service type | Fixed capability priority order ensures consistent, predictable mapping |
| Temperature unit mismatch | Wrong temperature values | Auto-detection from `temperatureScale` attribute, with Fahrenheit default. All internal values in Celsius |
| EventSocket broadcasts all events | Processing irrelevant events | Filter by `authorizedDeviceIds` set (populated from Maker API device list) |

## Resources

- [Hubitat Maker API Documentation](https://docs2.hubitat.com/en/apps/maker-api)
- [Hubitat Maker API Endpoints](https://docs2.hubitat.com/en/apps/maker-api/maker-api-endpoints)
- [Hubitat Device Capabilities](https://docs2.hubitat.com/en/developer/driver/capability-list)
- [Hubitat EventSocket](https://docs2.hubitat.com/en/developer/interfaces/eventsocket-interface)
- [Hubitat Community Forums](https://community.hubitat.com/)
- [Hubitat Safety Monitor (HSM)](https://docs2.hubitat.com/en/apps/hubitat-safety-monitor)
