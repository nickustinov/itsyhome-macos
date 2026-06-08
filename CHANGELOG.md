# Changelog

## 2.6.0

- Sensors in the menu – contact, motion, occupancy, leak, smoke, carbon monoxide and carbon dioxide sensors now appear as read-only rows showing their state (Open/Closed, Motion/Clear, Leak/Dry, Smoke/Clear, ...) with state-aware icons (#32)
- Individual temperature and humidity sensors – new "Summarise temperature and humidity" toggle in Settings → Advanced (on by default). When off, each temperature and humidity sensor is shown as its own row in the menu and in Settings → Accessories instead of a single aggregated per-room range
- Pin sensors to the menu bar – pinning any sensor now shows its reading next to the icon (e.g. 21.5°, 45 %, Smoke, Motion) and updates live
- Read-only sensors over webhooks – the binary sensor family is exposed through the local web server: `/list` and `/status` include them, `/info` adds a `detected` bool (reported as unknown when unreadable, never a false "clear"), `/debug` lists their characteristics, and value changes publish over the SSE `/events` stream
- Home Assistant sensor support – every HA sensor now appears in the menu. Contact, motion, occupancy, leak (moisture), smoke and carbon monoxide binary sensors map to their dedicated rows; any other numeric sensor (CO2, power, pressure, illuminance, air quality, ...) shows its value and unit, and any other binary sensor shows On/Off, each with a device-class icon. Diagnostic sensors stay governed by the entity category filter
- Battery indicator – battery-powered accessories show a small battery icon and percentage next to their name in the menu (sensors, locks, doors, blinds, garage doors and thermostats). Works with both HomeKit (sibling battery service) and Home Assistant (the device's battery sensor)

## 2.5.2

- Scene state + deactivate over webhooks. `/list/scenes` and `/info/scene/<name>` now include an optional `state: { on: Bool }` for HomeKit scenes that have a granular action list (omitted for HA snapshot scenes and other cases where the server can't introspect — clients should fall back to fire-only). The "active" computation matches what the menubar toggle uses: every action's target characteristic must match the device's current value within a per-characteristic tolerance (5 for position/brightness/speed, ~0 for booleans)
- New webhook endpoint `GET /off/scene/<name>` deactivates a scene with Apple Home semantics — turns off only what the scene turned on, never opens blinds or unlocks doors. Pair with the existing `GET /scene/<name>` (activate) to expose a full toggle UI on clients that previously only fired scenes
- `SceneStateHelper` extracted from `SceneMenuItem` so the menubar UI and the webhook layer share one source of truth for "is this scene active" and "deactivate this scene"

## 2.5.1

- Fix camera snapshots not auto-refreshing on subsequent panel opens – the snapshot and timestamp timers were torn down on close but only restarted via `viewDidAppear`, which doesn't fire on later opens; now restarted in `panelDidShow` so the timestamp ticks and snapshots refresh every 30s (#117)
- Fix camera panel dismissing when clicking inside the feed – the local click monitor compared window identity, so clicks landing on the panel's hosted/child windows were treated as outside; now uses screen-coordinate containment, matching the global monitor
- Expose `speedMin` / `speedMax` in `/info` JSON so webhook clients can render the correct fan speed scale and presets (HomeKit fans can override the 0–100 default — e.g. 0–6 on a 6-speed ceiling fan)
- Fix `/info` reporting stale `on` state for fans / AC / valves — prefer the `Active` characteristic over the `On` characteristic, matching what the menubar dropdown reads (`activeId ?? powerStateId`)
- Webhook list endpoints now respect the user's reordering from Settings → Accessories: `/list/rooms`, `/list/scenes`, `/list/groups`, `/list/groups/<room>`, `/list/devices`, and `/info/<room>` all emit items in the same order as the menubar dropdown. Hidden rooms, scenes, and services are also filtered out of `/list/*` responses (a specific `/info/<name>` lookup still works for hidden items)
- Webhook icon endpoint: `GET /icon/<phosphor-name>?fill=1&size=64` returns a PNG of the requested Phosphor icon rendered white on transparent. Lets clients render the same icons the menubar uses (including user-customised icons via `IconResolver`) without bundling the SVG set themselves
- `/list/rooms` now includes the Phosphor `icon` name for each room (paired with the new `/icon/<name>` endpoint), so clients can render the per-room icon the menubar already uses
- `/list/favourites` (alias: `/list/favorites`) returns the user's curated Favourites (services / device groups / scenes) with a `kind` discriminator and the same Phosphor icon names, so clients can render a unified "Favourites" affordance. Order matches the user's drag-ordered Favourites list in Settings
- Fix `/on` and `/off` returning "Action not supported" for thermostats and HA-bridged climate devices (e.g. Ecobee) – `executePowerState` only checked `powerStateId` / `activeId`, so devices that expose only `TargetHeatingCoolingState` fell through. Now mirrors the toggle path: on → auto (3), off → off (0); the Temperature submenu still lets the user pick heat/cool explicitly
- Auto-mode thermostat support (e.g. Ecobee in auto): `/info` ServiceState now emits `heatingThreshold` (lo) and `coolingThreshold` (hi) as separate fields when the service exposes them. The old fallback that synthesised a single `targetTemperature` from the cool threshold has been removed (it was masking the two-setpoint reality and the UI couldn't render auto-mode bands)
- New webhook endpoints for thermostats: `/mode/<off|heat|cool|auto>/<target>` changes the thermostat mode; `/heat/<temp>/<target>` and `/cool/<temp>/<target>` set the heating/cooling threshold independently for auto-mode devices
- Fix `/temp/<X>/<thermostat>` clobbering auto-mode bands – it used to write the same value to both heat and cool thresholds, so Ecobee silently rejected one side (it enforces a 1 °C minimum spread between lo and hi) and the UI looked unchanged while HA showed lo moved. `/temp` now writes only the cooling threshold (the "upper comfort bound") when no single targetTemperature characteristic exists; use the new `/heat` and `/cool` endpoints for explicit threshold control
- Fix Home Assistant light brightness off-by-one – `Int(b * 2.55)` and `Int(b / 2.55)` both truncated toward zero, so writing 50 % to HA stored 127/255 and read back as 49 %. Both conversions now round, so percentages round-trip exactly (or differ by at most 0 % across the boundary)
- Webhook `/mode/<m>/<target>` now respects the device's actual mode support and accepts HA-specific modes (`heat_cool`, `dry`, `fan_only`, …). `/info` ServiceState gains `availableModes` – a unified list of mode strings the device will accept (HA climate emits it directly; HK Thermostat / HeaterCooler get translated from their integer valid-state arrays plus the Active characteristic for "off"). The action engine validates writes against availability and returns failure instead of silently dropping unsupported modes. Power flow on HeaterCooler ACs flips Active alongside the mode write, mirroring the menubar's behaviour
- Fix `/info` reporting the wrong climate mode for HA-bridged devices using HA-specific modes. The bridge stores `heat_cool` as `3`, `dry` as `4`, `fan_only` as `5`, `auto` as `6` (extended beyond the HK 0-3 range), but the read-back used `TargetThermostatState` which only knows 0-3 with `3 = auto`. So `heat_cool` was reported as `auto`, and `dry` / `fan_only` / extended-`auto` all collapsed to `off` even though the device was actually running them. Read-back now uses the HA extended vocabulary when the service exposes `availableHVACModes`

## 2.5.0

- Fix RGB colour picker setting wrong colour on Hue lights
- Fix camera talk button not working (#114)
- Reduce idle battery usage from chatty HomeKit bridges (#113)
- Fix menu going blank after wake with SSID-based home switching (#112)
- Fix Home Assistant covers grouped in the wrong room when a single device spans multiple areas (#109)
- Return all matches from `/info/<room>/<device>` when multiple devices share the same name (#108)
- Reorder accessories inside rooms by drag in Settings → Accessories; right-click any accessory to add or remove dividers, or reset the room's order (#115)
- Add Home Assistant `input_boolean` support – treated like a switch with toggle on/off (#64)
- Add "Itsyhome for iOS" settings panel promoting the iPhone/iPad companion included with Pro

## 2.4.0

- **Open camera on motion (Pro)** – cameras with built-in motion sensors can now auto-open the camera stream when motion is detected; per-camera toggle in Settings → Cameras; works with both HomeKit and Home Assistant; includes 60-second cooldown to prevent repeated triggers (#34)
- **Separate auto-close settings card** – the auto-close camera popup settings are now in their own card, enabled whenever any auto-open trigger (doorbell or motion) is active
- **Fix group keyboard shortcut toggling lights individually** – using a keyboard shortcut to toggle a device group toggled each light's state independently (on→off, off→on) instead of treating the group as a whole; now matches menu behavior: if any device is on, all turn off; if all are off, all turn on (#101)
- **Fix camera motion auto-open bypassing preference check** – HomeKit motion events unconditionally triggered camera streaming even for cameras without motion-open enabled; now all motion events go through the macOS-side preference check before opening the panel or starting a stream (#34)
- **Fix Home Assistant entities ignoring per-entity area overrides** – entities assigned to a different area than their parent device were always grouped by the device's area; now entity-level area overrides take priority, matching Home Assistant's own behavior (#92)
- **Fix devices stuck grayed out** – HomeKit notification subscriptions are now throttled per-accessory to avoid overwhelming bridges (e.g. Hue); if a value update arrives for a device marked unreachable, it is automatically restored to reachable; already-subscribed characteristics are skipped on refresh

## 2.3.0

### Build 251
- **Suppress all runtime Home Assistant error popups** – HA connection and data errors are now logged silently instead of showing modal alerts; fixes disruptive popups on wake from sleep (#85)

### Build 249
- **Add double-click zoom for camera streams** – double-click on a camera stream to zoom in at 2× toward the click point, double-click again to zoom out; trackpad pinch-to-zoom also supported (1×–3×), pan while zoomed; overlays and controls stay fixed above the video; zoom resets when switching cameras or closing the stream (#76)

### Build 248
- **Add SSID-based auto-switching (Pro)** – automatically switch HomeKit home or Home Assistant server URL (with optional per-network access token) based on the current WiFi network; opt-in via Settings → Networks, requires Location Services permission for SSID reading

### Build 247
- **Fix thermostat not remembering last active mode** – devices like Tado Smart AC report `targetHeatingCoolingState: 0` when off, so after a menu rebuild the last active mode defaulted to Heat; now persists the last non-off mode to UserDefaults per device so the correct mode is restored on toggle

## 2.2.0
- **Fix Home Assistant entities grouped in wrong rooms** – room assignment for multi-entity devices (e.g. ESPSomfy RTS) was based on whichever entity happened to be iterated first from a dictionary, which changed randomly on each sync; now uses the device's own area directly, falling back to entity-level area only for standalone entities without a device
- **Fix invisible window interfering with tiling window managers** – the hidden 1×1 Catalyst window was ordered into the window list at launch, causing AeroSpace and similar tiling WMs to tile an invisible window; now blocked from ordering entirely and only briefly allowed when StoreKit needs a presentation context for purchases or restores
- **Add `/refresh` webhook endpoint** – triggers the same full data reload as the Refresh button in the menu bar; useful when webhook queries return stale HomeKit values for devices like Ecobee thermostats that don't always push characteristic updates reliably
- **Fix crash on wake from sleep in network monitor** – moved all mutable property access into the main queue dispatch to eliminate a data race between the `NWPathMonitor` callback and `handleSystemWake`
- **Suppress transient error alerts after wake from sleep** – timeout, connection, and disconnection errors during Home Assistant reconnection are no longer shown as alerts
- **Add security system state to webhook info endpoint** – the `/info/` webhook now returns `securityState` for security system devices
- **Fix "Message too long" error on large HA installations** – increased the WebSocket maximum message size from 1 MB to 16 MB

## 2.1.0
- **Security system arm/disarm via webhooks and URL schemes** – security systems can now be armed to a specific mode (stay, away, night) or disarmed through webhooks, URL schemes, and commands; previously only toggle was supported
- **Fix WebRTC streaming for Nest cameras** – the data channel label from `get_client_config` was looked up inside the `configuration` sub-object instead of at the top level; without the data channel the SDP offer lacked the required `m=application` line and Nest rejected it
- **Fix incorrect accessory name normalization** – room name stripping now requires a space after the room name, so "Garagenlicht" is no longer incorrectly shortened to "nlicht" in the "Garage" room
- **Fix lock groups not toggling** – added lock state reading on init and lock target writing on toggle, so lock groups now correctly lock/unlock all members
- **Snapshot polling fallback for cameras** – cameras that don't support WebRTC or HLS now fall back to polling `/api/camera_proxy` for JPEG snapshots at 1-second intervals
- **Simple light controls** – new toggle in Settings → Advanced to show only the on/off switch for lights
- **Advanced settings tab** – moved temperature units and simple light controls into a dedicated Advanced tab
- **Entity category filter setting** – new dropdown in Settings → Home Assistant to choose which entity categories to hide
- **Temperature unit setting** – new dropdown in General settings to override the system locale for temperature display
- **Auto-close doorbell camera popup** – new setting to automatically close the camera popup after a doorbell ring, with configurable delay
- **Fix HA connection stuck on "Connecting" forever** – `sendAndWait()` now has a 30-second timeout; `handleDisconnection()` now cancels all pending requests when the WebSocket drops
- **Detect local network permission denied** – shows a specific error directing the user to System Settings instead of silently failing
- **Auto-reconnect when network becomes available** – automatically reconnects to Home Assistant when the network path changes to satisfied
- **Fix http connections blocked on App Store builds** – replaced `NSAllowsLocalNetworking` with `NSAllowsArbitraryLoads` in ATS settings
- **Fix WebRTC streaming for Nest cameras** – the app now fetches `camera/webrtc/get_client_config` to detect cameras that need a data channel and reorders SDP m-lines
- **Fix cameras not showing without STREAM feature flag** – the filter now only excludes cameras with state "unavailable"
- **Camera debug endpoint** – new `/debug/cameras` webhook endpoint probes each camera's snapshot, HLS, and WebRTC support
- **Fix swing button shown on A/C units without "off" swing mode** – hidden for climate entities whose available swing modes don't include "off"
- **Localization** – translations for 12 languages
- **Fix crash on launch for some Home Assistant setups** – replaced duplicate-unsafe dictionary construction

## 2.0.0
- **Home Assistant support** – connect to a Home Assistant instance as an alternative to HomeKit, with support for climate, lights, fans, covers, locks, humidifiers, valves, garage doors, security systems, cameras (snapshots, WebRTC, and HLS streaming), and scenes
- **Dual RGB + color temperature support** – lights exposing both hue/saturation and color temperature (e.g. Govee Neon Rope 2 via Matter) now show both picker buttons and sliders instead of only one
- **Continuous color temperature slider** – the color temperature picker is now a horizontal warm-to-cool gradient bar instead of 5 discrete circle presets
- **Slider reflects light color** – the brightness slider tint updates to match the current RGB or color temperature of the light
- **Remember camera window position and size** – the camera panel remembers its position and size per camera, so reopening the same camera restores where you left it
- **SSE event stream** – new `/events` endpoint on the webhook server streams real-time device state changes via Server-Sent Events, usable with `curl -N`, browser `EventSource`, or any SSE client
- **Real-time accessory updates** – accessories now update instantly when toggled from the Home app or other controllers, instead of waiting for the menu to be opened; also re-reads characteristic values when a device becomes reachable again after being offline
- **Hide mode selector for single-mode climate devices** – heater-cooler and thermostat devices that only support one mode (e.g. heat-only radiators like Eve Thermo) no longer show the Cool/Heat/Auto mode selector; devices with two valid modes show only those two buttons
- **Fan speed control via webhooks and URL schemes** – fan rotation speed can now be set through webhooks (`/speed/50/Room/Fan`), URL schemes (`itsyhome://speed/50/Room/Fan`), and commands (`set speed 50 Room/Fan`), with automatic clamping to device min/max limits (contributed by [@loganprit](https://github.com/loganprit))
- **Group display options** – groups can now be shown as expandable submenus with individual device controls, not just a single toggle row; two new settings per group – "Group switch" and "Submenu" – control whether the toggle row and/or submenu are shown
- **Hide "Other" section** – the "Other" section (devices with no room) now has an eyeball toggle in Settings → Home to hide it from the menu, matching rooms and scenes
- **Default to https for remote HA URLs** – bare hostnames for remote services (Nabu Casa, DuckDNS, custom domains) now default to `https://` instead of `http://`, so the WebSocket connection uses `wss://` as required; local addresses (`.local`, private IPs, `localhost`) still default to `http://`
- **Add ATS local networking exception** – added `NSAllowsLocalNetworking` to App Transport Security so local `http://` and `ws://` connections aren't blocked by macOS
- **Fix crash when connecting to Nabu Casa cloud URLs** – the app no longer crashes when the Home Assistant server URL triggers an invalid WebSocket connection; URL scheme is now validated before connecting, and `wss://` URLs are accepted directly
- **Fix crash from concurrent state updates** – a data race in the entity state mapper that could cause crashes during rapid state changes is now fixed with proper thread synchronization
- **Fix crash when iCloud sync updates camera view** – iCloud sync notifications could arrive on a background thread, causing a crash when the camera collection view reloaded off the main queue; notifications are now dispatched to the main thread
- **Fix HA lock state always showing unlocked** – Home Assistant sends lock state as a string ("locked", "unlocked"), but the webhook server was converting it with `intValue()` which returned 0 for strings, causing all HA locks to appear unlocked
- **Fix HA climate toggle not working** – climate entities had `activeId` set which caused toggle to write to an unhandled "active" characteristic; removed `activeId` for climate so toggle correctly uses HVAC mode (off/auto)
- **Fix HA thermostat showing wrong temperature** – thermostats on Home Assistant instances configured for Fahrenheit showed doubled-converted values (e.g. 156° instead of 70°); the app now fetches the HA unit system at connect time and normalizes all temperatures to Celsius internally
- **Fix HA not reconnecting after Mac sleep** – the app now listens for system wake events and automatically reconnects to Home Assistant instead of staying stuck on "Loading Home Assistant..."
- **Fix roomless accessories not toggling via webhooks** – devices without a room (shown in "Other") could be read via `/info/` but not controlled via `/toggle/` because DeviceResolver had no bare device name resolution; added a new resolution step for unqualified device names
- **Fix CLI/webhook toggle failing until Refresh clicked** – after an HA reconnect, the action engine bridge reference is now updated immediately so CLI and webhook commands work without needing to click Refresh first
- **Fix pinned room not updating after hiding accessories** – toggling accessory visibility via the eye icon now immediately updates pinned room menus without needing to unpin and re-pin
- **Fix doorbell notifications ignoring disabled setting** – disabling "Show doorbell camera on ring" now correctly prevents both the camera stream and the doorbell sound from triggering
- **Fix camera snapshot timer draining battery** – the 30-second snapshot polling timer now stops when the camera panel is closed, preventing continuous wake-ups on battery-powered cameras
- **Fix group brightness turning on off lights** – dragging the brightness slider in a light group no longer turns on lights that were off
- **Fix group row disappearing on drag in settings** – dragging a group row in the Home settings tab when it was the only group in its section caused it to vanish; drag initiation is now blocked when there is only one group
- **Fix phantom window in Mission Control** – the app no longer appears as an empty window in Mission Control when "Group windows by application" is enabled

## 1.3.1

### Bug fixes
- **Fix camera-only rooms missing from settings** — rooms containing only cameras or unsupported sensors now appear in settings so they can be hidden

## 1.3.0

### New features
- **Doorbell notifications** — when a HomeKit doorbell rings, the camera panel automatically opens in the top-right corner with a live stream of the doorbell camera, pinned to the desktop
- **Doorbell sound** — plays a chime sound when a doorbell rings (configurable in Settings → Cameras)
- **Doorbell settings** — new toggles in Settings → Cameras to control automatic camera display and sound on doorbell rings

## 1.2.0

### New features
- **Per-camera aspect ratios** — cameras with non-16:9 native ratios (4:3, 1:1, vertical, etc.) are detected automatically and rendered without black bars in both grid and stream views
- **Pin camera to desktop** — pin button in stream mode keeps the camera window visible when clicking away, with floating window level and toggle support
- **Zoom stream button** — magnifying glass button in stream mode toggles between 1x and 2x window size
- **Strip room name from accessories in rooms** — accessories displayed in room submenus have the room name prefix removed (e.g. "Living Room AC" shows as "AC" in the Living Room submenu)

### Bug fixes
- **Fix pinned rooms ignoring hidden accessories** — accessories marked as hidden now stay hidden in pinned room menus, matching the main menu bar behaviour
- **Fix scene deactivation reversing all devices** — turning off a scene now only turns off devices the scene turned on, matching Apple Home behaviour; locks, garage doors, and already-off lights are no longer reversed
- **Fix pinned scenes not updating state** — pinned scenes now receive real-time characteristic updates, so activating one scene correctly deactivates others without needing to reopen the menu
- **Fix crash on launch with Home permission** — removed force-unwrapped UUID conversions in menu building that caused a crash when processing HomeKit data, preventing the menu bar icon from ever appearing
- **Fix sensor-only rooms missing from settings** — rooms containing only temperature/humidity sensors now appear in the settings room list so they can be hidden
- **Fix GitHub link in about section** — pointed to incorrect repository URL
- **Fix cameras not updating on home switch** — camera panel now reloads when switching between homes, stopping any active stream and showing the new home's cameras
- **Fix crash with duplicate room names** — homes with identically named rooms no longer crash on launch

## 1.1.0

Initial release.
