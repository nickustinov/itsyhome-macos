# Changelog

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
