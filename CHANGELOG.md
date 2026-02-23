# Changelog

## 2.1.0

### Build 232
- **Temperature unit setting** – new dropdown in General settings to override the system locale for temperature display; choose between System default, Celsius, or Fahrenheit

### Build 231
- **Auto-close doorbell camera popup** – new setting to automatically close the camera popup after a doorbell ring, with configurable delay (30s, 1m, 2m, 5m) to help preserve battery on doorbell cameras; the timer cancels when the user interacts with the panel (click, move, or resize)

### Build 230
- **Fix HA connection stuck on "Connecting" forever** – `sendAndWait()` now has a 30-second timeout so API calls no longer hang indefinitely if the server is slow or a response is lost; additionally, `handleDisconnection()` now cancels all pending requests when the WebSocket drops mid-session, matching the cleanup that `disconnect()` already performed
- **Detect local network permission denied** – a network monitor now detects when macOS blocks local network access and shows a specific error directing the user to System Settings, instead of silently failing to connect
- **Auto-reconnect when network becomes available** – the app automatically reconnects to Home Assistant when the network path changes to satisfied (e.g. after wake from sleep or Wi-Fi reconnect), and suppresses error alerts for transient network failures

### Build 229
- **Fix http connections blocked on App Store builds** – replaced `NSAllowsLocalNetworking` with `NSAllowsArbitraryLoads` in App Transport Security settings, matching the official HA companion app; the previous setting only covered `.local` domains and bare IPs, blocking users who connect to their HA instance via custom DNS names or hostnames with dots

### Build 228
- **Fix WebRTC streaming for Nest cameras** – Nest cameras require an SDP offer with three m-lines in audio → video → application order; the app now fetches `camera/webrtc/get_client_config` to detect cameras that need a data channel (e.g. Nest), creates the data channel before generating the offer, and reorders the SDP m-lines to match the expected order

### Build 227
- **Fix cameras not showing without STREAM feature flag** – cameras from integrations like Frigate and Blue Iris that don't set the `supported_features` STREAM bit are now shown; the filter now only excludes cameras with state "unavailable"
- **Camera debug endpoint** – new `/debug/cameras` webhook endpoint probes each camera's snapshot, HLS, and WebRTC support, with per-entity filtering via `/debug/cameras/{entity_id}`

### Build 226
- **Fix swing button shown on A/C units without "off" swing mode** – the swing toggle is now hidden for climate entities whose available swing modes don't include "off", since the button can only toggle between off and on

### Build 225
- **Localization** – added full localization support with translations for 12 languages: Spanish, French, German, Italian, Portuguese (Brazil), Russian, Polish, Japanese, Korean, Chinese Simplified, Chinese Traditional
- **Fix crash on launch for some Home Assistant setups** – building the favourites menu with `Dictionary(uniqueKeysWithValues:)` crashed when duplicate service identifiers were present; replaced with duplicate-safe dictionary construction

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
