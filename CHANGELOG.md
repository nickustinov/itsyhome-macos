# Changelog

## Unreleased

### New features
- **Per-camera aspect ratios** — cameras with non-16:9 native ratios (4:3, 1:1, vertical, etc.) are detected automatically and rendered without black bars in both grid and stream views
- **Pin camera to desktop** — pin button in stream mode keeps the camera window visible when clicking away, with floating window level and toggle support
- **Zoom stream button** — magnifying glass button in stream mode toggles between 1x and 2x window size

### Bug fixes
- **Fix crash on launch with Home permission** — removed force-unwrapped UUID conversions in menu building that caused a crash when processing HomeKit data, preventing the menu bar icon from ever appearing
- **Fix sensor-only rooms missing from settings** — rooms containing only temperature/humidity sensors now appear in the settings room list so they can be hidden
- **Fix GitHub link in about section** — pointed to incorrect repository URL
- **Fix cameras not updating on home switch** — camera panel now reloads when switching between homes, stopping any active stream and showing the new home's cameras
