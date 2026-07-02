# Known issues

Findings from a full codebase review (2026-07-02), ranked by priority. Webhook authentication and `/debug/*` exposure were reviewed and accepted by design: the server is off by default, enabling it is an explicit user action, and tens of third-party apps depend on the API staying as-is – no changes there.

Legend: file references are `path:line` at the time of review; lines may drift.

---

## P1 – wrong physical action / safety

### 1. Locks and garage doors fail open when state is unknown
`macOSBridge/MacOSController+PinnedItems.swift:200-203, 212-215`

In `toggleService`, lock state defaults to `?? 1` (locked) and garage door state to `?? 1` (closed) when `getCharacteristicValue` returns nil (unreachable device, or pre-first-read at startup). The toggle then writes `0` – so a hotkey press actuates toward **unlocked/open** instead of doing nothing.

**Fix:** when cached state is nil, no-op (optionally show a "state unknown" notification) instead of assuming the secure state.

### 2. HA lock groups can never be locked via hotkey
`macOSBridge/MacOSController+PinnedItems.swift:170-171`

`toggleGroup` reads lock state with `as? Int ?? 1`, but the HA bridge stores `lock_state` as a String (`"locked"`/`"unlocked"`, see `EntityMapper.swift:775`). The cast always fails, `anyOn` is always true, and the group hotkey **always writes unlock** – even when everything is already unlocked.

**Fix:** handle the String encoding (or normalise lock state to one type at the bridge boundary).

### 3. Triggered or vacation-armed alarm displays as "Disarmed"
`macOSBridge/MenuItems/HASecuritySystemMenuItem.swift:223-244`

Two related bugs:
- `targetStateId` updates are written into `currentState`, and `mapAlarmTargetToHomeKit("triggered")` yields 3 (disarmed); when the target update lands after the state update, an actively triggered alarm renders as disarmed (`:223`).
- Remote int updates can never map back to `armed_vacation`/`armed_custom_bypass` (EntityMapper's int encoding defaults them to 3), so a vacation-armed panel shows "Disarmed" once the 10 s local suppression expires (`:224-244`).

Also: the 10 s suppression window swallows genuine `triggered` updates (`:219`).

**Fix:** never map `triggered` or unknown armed modes to disarmed; let `triggered` bypass suppression.

---

## P2 – data loss and stuck state

### 4. Silent decode failure wipes automations and virtual devices
`macOSBridge/Automations/AutomationStore.swift:20-25`, `macOSBridge/HAPBridge/VirtualDeviceStore.swift:24-29`

`try? JSONDecoder().decode(...)` failure (schema drift after downgrade, corrupt blob) silently resets to `[]`; the first subsequent `persist()` overwrites the stored blob, destroying all automations/virtual devices with no error, log, or backup. Losing `VirtualDevice` records also desyncs the HAP bridge from tiles still paired in Apple Home.

**Fix:** on decode failure, log and keep the old blob (rename to `.corrupt` backup) instead of persisting the empty state.

### 5. History lost on quit; flush can be starved indefinitely
`macOSBridge/History/HistoryStore.swift:162-168, 61-66`

- `scheduleFlush()` cancels and reschedules the 2 s debounce on every sample with no maximum interval – a chatty bridge that never leaves a 2 s quiet gap keeps history in memory only.
- No quit path calls `flush()` (despite the comment claiming app-termination flushes; only the Pro-lapse branch in `ProManager.swift:129` does). Quit or crash loses everything since the last quiet period.
- `configure()` (called from every `rebuildMenu`, `MacOSController.swift:807`) cancels the pending save and reloads from disk, silently discarding the last ~2 s of samples even when the home id is unchanged.

**Fix:** add a max flush interval (e.g. 30 s), flush on `applicationWillTerminate`, and skip the reload in `configure()` when the home id is unchanged.

### 6. Cloud sync prunes unresolvable favourites and propagates the deletion
`macOSBridge/Sync/CloudSyncManager.swift:202-208`, `macOSBridge/Sync/CloudSyncTranslator.swift:90-104`

On pull, stable names that don't resolve against current MenuData (accessory unreachable, mid-discovery, renamed room) are dropped by `compactMap`; the pruned array overwrites local defaults, and the next `handleLocalChange` uploads the pruned set back to the cloud – permanently deleting those favourites/hidden ids on every synced device.

**Fix:** keep unresolvable stable names in the stored set (only hide them from the resolved view) so they survive until the accessory reappears.

### 7. Automation engine leaves virtual sensors stuck ON
`macOSBridge/Automations/AutomationEngine.swift:200-205, 99-122`

- Re-pulse race: the pulse timer writes OFF, then schedules an unconditional ON via `asyncAfter(+1 s)`. If the trigger clears in that window, `deactivate()` (`:179`) invalidates the timer and writes OFF, but the already-queued ON fires afterwards – a virtual leak/smoke sensor stays active in Apple Home with nothing to clear it.
- `load()`/`stop()` wipe `runtimes` without deactivating active ones, so disabling/deleting an active automation (all `AutomationsSection.swift:491/500/519` paths call `reload()`) or a Pro lapse (`ProManager.swift:128`) leaves the sensor permanently ON; the fresh runtime starts `active = false` so it never clears.
- `reload()` also rebuilds all runtimes on any store change, resetting every armed automation's duration countdown (a "door open 15 min" alert restarts from 0 when an unrelated automation is renamed).

**Fix:** guard the queued re-pulse ON behind a generation/active check; deactivate active runtimes in `stop()`/before `load()`; preserve runtimes whose automations are unchanged on reload.

---

## P3 – reliability and correctness

### 8. Webhook requests drive AppKit/HomeKit and unsynchronized state off the main thread
`macOSBridge/Webhook/WebhookServer.swift:191-193, 341`

Connections run on the webhook queue and `handleRequest` calls `actionEngine.execute` synchronously there. Consequences:
- `onCharacteristicWrite` → `MacOSController.updateMenuItems(..., isLocalChange: true)` (`MacOSController.swift:818-820`) bypasses the menu-closed guard (`MacOSController+MenuUpdates.swift:32`) and walks NSMenu / updates NSStatusItem off main.
- `HistoryStore.record` mutates its unlocked `series`/`sessions` dictionaries (`HistoryStore.swift:74-110`) concurrently with main-thread writes.
- In HomeKit mode, `HomeKitManager.writeCharacteristic`/`findCharacteristic` traverse and write the HMHome graph off main (`HomeKitManager+Commands.swift:64-96`); `/refresh` rebuilds `homes/rooms/accessories/scenes` arrays with no synchronization (`HomeKitManager+DataFetching.swift:18-31`).
- Read endpoints read `engine.menuData` (plain `var` written on main) from the queue (`WebhookServer.swift:362`).

A webhook arriving while the menu is open can corrupt state or crash in AppKit's main-thread checker. **Internal fix only, no API change:** dispatch the engine work in `handleRequest` to the main queue.

### 9. HomeAssistantClient: zombie reconnects, dead keepalive, duplicate disconnect paths
`Itsyhome/HomeAssistant/HomeAssistantClient.swift`

- **Zombie clients** (`:163-187, 124, 127`): `disconnect()` cancels the socket but sets no "intentionally closed" flag, so the failed `receive` → `handleDisconnection` → `scheduleReconnect` (`:349-371`) revives it. The client can never deallocate because its `URLSession(configuration:delegate:delegateQueue:)` retains it and is never invalidated (`deinit` unreachable). Every wake/network-change/SSID switch builds a new platform (`MacOSController.swift:258-274, 372-376, 413-418`); each old client reconnects 1–30 s later and stays authenticated with `delegate == nil`. Days of sleep/wake → N leaked authenticated WebSockets.
- **Keepalive never runs** (`:246-263, 375-381`): `startPingPong` uses `Timer.scheduledTimer` on the URLSession delegate queue (no run loop) – `sendPing`/pong-timeout (`:390-409`) are dead code. Silent network drops are never detected; menu shows stale state indefinitely.
- **Double-schedule race** (`:200-203, 765-768, 420-425`): receive-failure, `didCloseWith`, and send-error paths all call `handleDisconnection`, each scheduling a reconnect; two concurrent `connect()` tasks race on the unsynchronized `webSocketTask` var (`:136-141`), orphaning receive loops.
- **Unsynchronized scalars** (`:150-159, 250-251, 326, 361`): `isAuthenticated`, `reconnectAttempts` mutated from two queues; also `HomeAssistantPlatform.cachedMenuDataJSON` (`HomeAssistantPlatform.swift:130, 147-149`).

**Fix:** an `isClosed` flag checked before reconnect; `session.finishTasksAndInvalidate()` in `disconnect()`; single-path disconnection handling; `DispatchSourceTimer` on a known queue for ping; confine state to one queue.

Related: `handleSystemWake` skips the `isConnectingToHA` guard the path monitor uses (`MacOSController.swift:258-274` vs `:292`) – wake during in-flight connect runs two concurrent `connect()` tasks.

### 10. Motion sensor updates never reach the menu, pinned items, or SSE
`Itsyhome/iOS/HomeKitManager+Motion.swift:50-72`, `Itsyhome/iOS/HomeKitManager.swift:217-222`

`handleMotionEventIfNeeded` returns true on every motion path (cleared, non-camera, camera), so `updateCharacteristic` is never forwarded. Pinned HomeKit motion sensors, sensor menu rows, and the SSE motion stream never see changes; the dropdown only recovers via the explicit read on menu open. Same early-return structure also skips unreachable-recovery for doorbell/motion events (`HomeKitManager.swift:214-232`).

**Fix:** return false (forward) after handling the camera-snapshot side effect.

### 11. Leaked keyDown monitor swallows all keyboard input
`macOSBridge/Controls/ShortcutButton.swift:77`

The local `keyDown` monitor is never removed in `deinit`. Closing the settings window (or rebuilding the row) mid-recording leaves a monitor installed forever whose closure returns nil for every keyDown – permanently eating keyboard input app-wide until relaunch.

**Fix:** remove the monitor in `deinit` (and on window close).

### 12. NaN crash in ModernSlider on degenerate metadata
`macOSBridge/DesignSystem/ModernSlider.swift:139, 269-270`

No min==max guard in `(value-min)/(max-min)`. Fan/purifier speed min/max come straight from device metadata; min==max produces a NaN CALayer frame and a CoreAnimation exception on menu open.

**Fix:** guard `max > min`, else treat as 0/hidden.

### 13. Open dropdown wiped mid-interaction on HA reconnect
`macOSBridge/MacOSController.swift:449-455, 626-628`

`processMenuJSON`/`platformDidDisconnect` rebuild the menu directly, without the `menuIsOpen`/`needsRebuild` deferral that `preferencesDidChange` uses. An HA reconnect (e.g. network path change) empties the menu under the user's cursor.

### 14. Fan speed writes bypass the write helper
`macOSBridge/ActionEngine/ActionEngine.swift:430` (vs helper at `:276`)

`executeSpeed` calls `bridge.writeCharacteristic` directly, so fan-speed is the only action that never fires `onCharacteristicWrite` – pinned status items, SSE clients, the automation engine, and history capture don't see the change. Also `:423-425` clamps 0 up to `rotationSpeedMin`, so "set speed 0" reports success but leaves the fan running at minimum.

### 15. Climate mode changes to auto/dry/fan_only don't propagate to siblings
`macOSBridge/MenuItems/HAClimateMenuItem.swift:578-581, 409-431`

`setMode` notifies siblings with a String but `updateValue`'s `targetStateId` branch only parses ints – the room copy/pinned item keeps the stale mode.

---

## P4 – UI and settings bugs

### 16. "Add divider above" corrupts saved accessory order across rooms
`macOSBridge/Settings/AccessoriesSettingsView+Tables.swift:269`

`case .header: if inRoom { break }` breaks the switch, not the loop – with two rooms expanded, the second room's service ids and separators are persisted into the first room's order. The sibling loop at `AccessoriesSettingsView+TableDelegate.swift:574` does it correctly with `return`.

### 17. Shortcuts recorded on group favourites never fire
`macOSBridge/Settings/AccessoryRowView.swift:351-356`, `macOSBridge/MacOSController+PinnedItems.swift:114-136`

Stored under `"groupFav:<groupId>"` but the hotkey dispatcher matches only raw scene/group/service ids – the recorded hotkey silently does nothing.

### 18. Drag-reorder bugs in accessories settings
`macOSBridge/Settings/AccessoriesSettingsView+TableDelegate.swift:425-443, 453-465`

- Favourites: drag indices are into the filtered list but `moveFavourite` indexes unfiltered `orderedFavouriteIds`; stale entries are guaranteed (see issue 25), so reorders shift the wrong element and persist it.
- Rooms: end-drop index is decremented twice – dragging a room to the bottom lands second-to-last.

### 19. Pinned sensors blank at launch
`macOSBridge/PinnedAccessory/PinnedStatusItem.swift:127-139`

`loadInitialValues()` omits all sensor ids (`contactSensorStateId`, `motionDetectedId`, `leakDetectedId`, `sensorReadingId`, …) that `statusDisplay` uses – a pinned contact/temperature/leak sensor shows nothing until the first live change.

### 20. Shared cached NSImage mutated by consumers
`macOSBridge/PinnedAccessory/PinnedStatusItem.swift:98`, `macOSBridge/DesignSystem/PhosphorIcon.swift:41-43`, `macOSBridge/Settings/Sections/CamerasSection.swift:642`

`PhosphorIcon.loadIcon` returns the cache instance and callers set `.size` on it – opening the camera accessory picker resizes the pinned menu-bar icon (and vice versa). Return a copy.

### 21. Pro purchase doesn't unlock bridge/history toggles until restart
`macOSBridge/Settings/SettingsView.swift:265-286`

`handleProStatusChanged` doesn't invalidate `homeKitBridgeSection` (`HomeKitBridgeSection.swift:60, 131`) or `advancedSection` (`AdvancedSection.swift:172`), whose enabled state is set once at init.

### 22. "Get Pro" from the custom-icon alert navigates nowhere
`macOSBridge/Settings/AccessoriesSettingsView+Tables.swift:43`

Posts `navigateToSectionNotification` with `object:` instead of the `userInfo: ["index": n]` the handler (`SettingsView.swift:260-263`) requires.

### 23. Group brightness slider doesn't apply brightness to off lights
`macOSBridge/MenuItems/GroupMenuItem+Actions.swift:66-93`

The all-off branch powers lights on but never writes the dragged brightness – slider shows 30 %, lights come on at their old level; cached `brightnessStates` diverge for off lights in mixed groups.

### 24. FlowLayoutView renders bottom-up and height goes stale
`macOSBridge/DesignSystem/FlowLayoutView.swift:24, 48-66`

Unflipped view lays the first row at the visual bottom (wrapped camera chips vertically inverted); `intrinsicContentSize` reads superview width at invalidation time and is never re-invalidated on resize, so wrapped content overlaps what follows.

### 25. Group deletion orphans per-home state
`macOSBridge/Settings/PreferencesManager+Groups.swift:48-53`

Leaves `groupFav:` favourites, `pinnedItemIds`, custom icons, and favourites-row shortcuts behind – feeds issues 6 and 18.

---

## P5 – minor / polish

- **Jammed lock displayed as unlocked** – `macOSBridge/MenuItems/LockMenuItem.swift:118`. States 2 (jammed)/3 (unknown) map to "Unlocked"; a row click then writes lock believing it toggles from unlocked.
- **Obstructed garage door still commandable via row click** – `macOSBridge/MenuItems/GarageDoorMenuItem.swift:103-114` (toggle disabled at `:173` but `onAction` has no guard).
- **`setReachable(true)` re-enables deliberately disabled controls** – `macOSBridge/MenuItems/BaseMenuItems.swift:37-50` (affordance-only; action handlers re-guard).
- **Unknown lock in a group defaults to "locked"** – `macOSBridge/MenuItems/GroupMenuItem+StateManagement.swift:59`; first group click unlocks instead of locking.
- **Group colour-temp range: last light wins, not intersection** – `GroupMenuItem+StateManagement.swift:97-104`; can write out-of-range mireds to narrower-range bulbs.
- **Circular hue averaged arithmetically** – `GroupMenuItem+StateManagement.swift:119, 210`; two reds (350°, 10°) display as cyan (display-only).
- **Hardcoded temperature clamps ignore device range** – `macOSBridge/MenuItems/HAClimateMenuItem.swift:587, 621, 632`; also `ThermostatMenuItem.swift:409, 442, 453`, `ACMenuItem.swift:432, 500, 511`. A 32 °C setpoint is rewritten to 30 on first stepper press; sub-10 °C unreachable.
- **Swing button shown for devices without "auto" swing mode** – `HAClimateMenuItem.swift:100-102, 659-666`; write path hardcodes "auto" (`HomeAssistantPlatform+Actions.swift:383`), HA rejects it.
- **HA valve: 60 s suppression drops genuine remote position updates** – `macOSBridge/MenuItems/HAValveMenuItem.swift:170`.
- **HA lock siblings show final state during transition/failure** – `macOSBridge/MenuItems/HALockMenuItem.swift:196`.
- **Alarm wrong-code re-prompt is dead code + observer leak** – `HASecuritySystemMenuItem.swift:342-357, 391-414`. `hideCodeEntry()` nils `pendingMode` before the error arrives (rejected code silently shows "disarmed", no re-prompt); the `.alarmCommandFailed` observer (registered `object: nil`, removed only in the handler) survives successful commands and later reverts the item to hardcoded "disarmed".
- **Separator bugs** – divider before every appended service in custom-ordered rooms (`macOSBridge/MenuBuilder.swift:320-332`, `lastWasDivider` never reset); stray leading separator in pinned room menus (`PinnedStatusItem+Menu.swift:52`); room `GroupMenuItem`s refreshed twice per event (`PinnedStatusItem+Menu.swift:50, 58`).
- **nil doorbell event value treated as a ring** – `Itsyhome/iOS/HomeKitManager+Doorbell.swift:58-62` (`as? Int ?? 0` = single press opens the panel).
- **Menu-bar status strings hardcoded English** – `macOSBridge/PinnedAccessory/PinnedStatusItem+StatusDisplay.swift:179, 201-207, 225-235` ("Jammed", "Opening", "Away", …).
- **Automation duration `Int(...) ?? 0` silently saves 0** – `macOSBridge/Settings/Sections/AutomationsSection.swift:472-483`; "1.5"/"1,5" becomes fire-immediately, `errorLabel` unused.
- **HA network rules: token in plaintext UserDefaults, no URL validation** – `macOSBridge/Settings/PreferencesManager+Networks.swift:19-24, 82-95`, `NetworksSection.swift:534-538`. Inconsistent with the primary token, which lives in the Keychain (`HAAuthManager.swift:140-201`).
- **Group device order scrambled on every save** – `macOSBridge/Settings/Sections/GroupEditorPanel.swift:330` serializes a `Set`; `DeviceGroup.resolveServices` preserves that nondeterministic order.
- **Function-key display map wrong** – `macOSBridge/Controls/ShortcutButton.swift:155-156`. keyCode 119 is End (shown "F2"), 120 is F2 (shown "F1"); stored codes are correct, display is wrong.
- **`VirtualControl.setState` HAP pushes unordered** – `macOSBridge/HAPBridge/VirtualControl.swift:32`; rapid state changes can reach the bridge out of order.
- **`HACameraSignaling` leaks one object + URLSession per stream** – `Itsyhome/iOS/HACameraSignaling.swift:43-48`; session with `delegate: self` never invalidated, `deinit` unreachable (memory-only; sockets closed by the VC).
- **Synchronous history disk I/O on main** – `HistoryStore.configure` (from `rebuildMenu`) reads + decodes synchronously; debounced `flush()` encodes up to 20 000 samples per sensor on main every 2 s (`HistoryStore.swift:58-67, 162-174`, `HistoryStorage.swift:62-67`). Beachballs with a month of history.
- **CameraPanelManager monitors add-only** – `macOSBridge/CameraPanelManager.swift:349-373, 500-513`. `autoCloseClickMonitor` and move/resize observers are never removed; recreating the cameras window accumulates handlers retaining dead windows.
- **`URLSchemeHandler` double percent-decodes targets** – `Itsyhome/Shared/URLSchemeHandler.swift:86, 97-146`; device names containing literal `%XX` get mangled.
- **CoverControl doc comment inverts open/close** – `macOSBridge/DesignSystem/CoverControl.swift:41` says 0=close/2=open; implementation (`:332-344`) and the sole caller do the opposite.
- **ATS fully disabled globally** – `Itsyhome/Info.plist:77-81` (`NSAllowsArbitraryLoads`). Broader than the local-http need; `NSAllowsLocalNetworking` would cover it without disabling ATS for remote hosts. Low priority per product decision.

---

## Reviewed and clean

- Keychain handling for the primary HA token (`HAAuthManager.swift`) – correct class, accessibility, delete-before-add; no token logging.
- Pro/receipt validation (`macOSBridge/Pro/`) – StoreKit 2 `.verified` checks, debug overrides are compile-time `false`.
- Cloud sync scope – no credentials in `NSUbiquitousKeyValueStore`.
- No TLS-validation overrides anywhere in code.
- `ValueConversion.swift` and core unit math (F→C etc.) correct.
- Menu-item `onAction` closures use `[weak self]`; AutomationEngine main-confinement; SSE state queue-confined; camera VC timers invalidated; `DebugMockAccessories` clean.
