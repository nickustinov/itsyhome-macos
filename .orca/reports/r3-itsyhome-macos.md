# r3-itsyhome-macos — Fix colour-setting scenes detected as inactive (#157)

**Concern:** HomeKit scenes that set `hue` / `saturation` were permanently reported
inactive by `SceneStateHelper.isActive(scene:bridge:)` because those characteristics
fell through to the `0.01` default tolerance, while HomeKit stores scene target values
as full-precision doubles and lamps report rounded integers.

**Fix:** one new `switch` case in `SceneStateHelper.tolerance(for:)` → `1.0` for
`CharacteristicTypes.hue` and `CharacteristicTypes.saturation`.

**Gate:** headless `macOSBridgeTests` bundle only (`xcodebuild test`, code signing
disabled). No `.app` run, no HomeKit/Hue hardware.

---

## 1. Exact diff

```diff
diff --git a/CHANGELOG.md b/CHANGELOG.md
index d62f5a33..3897ebd8 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -19,6 +19,7 @@
 - Groups reorder anywhere in their room – a group row can be dragged among the room's accessories (previously groups were pinned to the top and a lone group couldn't be dragged at all), and every group and accessory row now shows a drag handle
 - Expand groups in Settings → Home – groups have a chevron revealing their member devices, and dragging those reorders the group. The group's submenu in the menu and its pinned menu-bar dropdown now follow that order instead of regrouping by type, and pinned room dropdowns follow the room's custom order too
 - Fix "Record sensor history" staying greyed out after buying Pro – the Advanced pane checked the Pro status only when it was first shown, so the toggle stayed disabled until the app was relaunched; it now unlocks the moment the purchase completes. The HomeKit bridge pane had the same stale gate (enable switch and upsell banner) and now rebuilds on Pro status changes like the other Pro panes
+- Fix colour-setting scenes never being detected as active – hue and saturation now use the same rounding tolerance as brightness/position, so a scene that set a colour is shown as active right after it fires instead of permanently "off" (#157, thanks @YuriNachos)

 ## 2.7.0

diff --git a/macOSBridge/Webhook/SceneStateHelper.swift b/macOSBridge/Webhook/SceneStateHelper.swift
index bbcb9477..d5972a0f 100644
--- a/macOSBridge/Webhook/SceneStateHelper.swift
+++ b/macOSBridge/Webhook/SceneStateHelper.swift
@@ -47,6 +47,9 @@ enum SceneStateHelper {
              CharacteristicTypes.brightness,
              CharacteristicTypes.rotationSpeed:
             return 5.0
+        case CharacteristicTypes.hue,
+             CharacteristicTypes.saturation:
+            return 1.0
         default:
             return 0.01
         }
diff --git a/macOSBridgeTests/SceneMenuItemTests.swift b/macOSBridgeTests/SceneMenuItemTests.swift
index dc74f66a..65b3f4f0 100644
--- a/macOSBridgeTests/SceneMenuItemTests.swift
+++ b/macOSBridgeTests/SceneMenuItemTests.swift
@@ -105,4 +105,53 @@ final class SceneMenuItemTests: XCTestCase {
         let result = SceneStateHelper.offValue(for: action(type: CharacteristicTypes.targetDoorState, target: 1.0))
         XCTAssertNil(result)
     }
+
+    // MARK: - Colour characteristic tolerance (#157)
+
+    func testToleranceForHueAndSaturation() {
+        XCTAssertEqual(SceneStateHelper.tolerance(for: CharacteristicTypes.hue), 1.0)
+        XCTAssertEqual(SceneStateHelper.tolerance(for: CharacteristicTypes.saturation), 1.0)
+    }
+
+    func testColourSceneWithinRoundingToleranceIsActive() {
+        let charId = UUID()
+        let bridge = SceneStubBridge()
+        bridge.values[charId] = 244                       // device reports a rounded int
+        let scene = SceneData(uniqueIdentifier: UUID(), name: "Cosy",
+                              actions: [SceneActionData(characteristicId: charId,
+                                                        characteristicType: CharacteristicTypes.hue,
+                                                        targetValue: 244.6013061341441)])  // delta 0.60
+        XCTAssertEqual(SceneStateHelper.isActive(scene: scene, bridge: bridge), true)
+    }
+
+    func testColourSceneOutsideToleranceIsInactive() {
+        let charId = UUID()
+        let bridge = SceneStubBridge()
+        bridge.values[charId] = 200                       // delta |244.6013 - 200| = 44.6, far above any tolerance
+        let scene = SceneData(uniqueIdentifier: UUID(), name: "Cosy",
+                              actions: [SceneActionData(characteristicId: charId,
+                                                        characteristicType: CharacteristicTypes.hue,
+                                                        targetValue: 244.6013061341441)])
+        XCTAssertEqual(SceneStateHelper.isActive(scene: scene, bridge: bridge), false)
+    }
+}
+
+// Minimal Mac2iOS stub so isActive(scene:bridge:) can be driven in tests.
+private final class SceneStubBridge: NSObject, Mac2iOS {
+    var values: [UUID: Any] = [:]
+    var homes: [HomeInfo] = []
+    var selectedHomeIdentifier: UUID?
+    var rooms: [RoomInfo] = []
+    var accessories: [AccessoryInfo] = []
+    var scenes: [SceneInfo] = []
+    func reloadHomeKit() {}
+    func executeScene(identifier: UUID) {}
+    func readCharacteristic(identifier: UUID) {}
+    func writeCharacteristic(identifier: UUID, value: Any) {}
+    func getCharacteristicValue(identifier: UUID) -> Any? { values[identifier] }
+    func openCameraWindow() {}
+    func closeCameraWindow() {}
+    func setCameraWindowHidden(_ hidden: Bool) {}
+    func getRawHomeKitDump() -> String? { nil }
+    func getCameraDebugJSON(entityId: String?, completion: @escaping (String?) -> Void) { completion(nil) }
+}
```

The 4th owned path is this report file itself (`.orca/reports/r3-itsyhome-macos.md`), added wholesale.

---

## 2. RED gate — tests added, source UNFIXED (expected failure)

Command:

```
xcodegen generate && xcodebuild test -scheme Itsyhome -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:macOSBridgeTests/SceneMenuItemTests
```

Result — the two positive tests fail exactly as predicted; the negative anchor passes:

```
SceneMenuItemTests.swift:112: error: -[macOSBridgeTests.SceneMenuItemTests testToleranceForHueAndSaturation] : XCTAssertEqual failed: ("0.01") is not equal to ("1.0")
SceneMenuItemTests.swift:113: error: -[macOSBridgeTests.SceneMenuItemTests testToleranceForHueAndSaturation] : XCTAssertEqual failed: ("0.01") is not equal to ("1.0")
SceneMenuItemTests.swift:124: error: -[macOSBridgeTests.SceneMenuItemTests testColourSceneWithinRoundingToleranceIsActive] : XCTAssertEqual failed: ("Optional(false)") is not equal to ("Optional(true)")
	 Executed 18 tests, with 3 failures (0 unexpected) in 1.638 (1.641) seconds
** TEST FAILED **
```

Exit code `65` (test failure, not a build error). `testColourSceneOutsideToleranceIsInactive`
is absent from the failure list → it passes on stock `main` (delta 44.6 ≥ any tolerance).

---

## 3. GREEN gate — fix applied, same targeted class

Same command re-run after adding the `hue`/`saturation` → `1.0` case:

```
	 Executed 18 tests, with 0 failures (0 unexpected) in 0.008 (0.014) seconds
** TEST SUCCEEDED **
```

Exit code `0`. All 18 `SceneMenuItemTests` pass (15 pre-existing + 3 new).

---

## 4. Mutation (anti-theater) check — fix reverted, tests retained

`git stash push -- macOSBridge/Webhook/SceneStateHelper.swift` (tests kept, production
fix reverted), then the same targeted gate re-run:

```
SceneMenuItemTests.swift:124: error: -[macOSBridgeTests.SceneMenuItemTests testColourSceneWithinRoundingToleranceIsActive] : XCTAssertEqual failed: ("Optional(false)") is not equal to ("Optional(true)")
SceneMenuItemTests.swift:112: error: -[macOSBridgeTests.SceneMenuItemTests testToleranceForHueAndSaturation] : XCTAssertEqual failed: ("0.01") is not equal to ("1.0")
SceneMenuItemTests.swift:113: error: -[macOSBridgeTests.SceneMenuItemTests testToleranceForHueAndSaturation] : XCTAssertEqual failed: ("0.01") is not equal to ("1.0")
	 Executed 18 tests, with 3 failures (0 unexpected) in 0.857 (0.860) seconds
** TEST FAILED **
```

Exit code `65`. The two positive tests fail again the moment the production change is
gone → the tests genuinely guard the behaviour, they do not pass vacuously. Fix restored
with `git stash pop` (verified `hue` case + `return 1.0` back in place; default still
`0.01`; the four original cases still `5.0`).

---

## 5. Full GATE — all `macOSBridgeTests`

```
xcodegen generate
xcodebuild test -scheme Itsyhome -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

First committed-state run — green:

```
	 Executed 990 tests, with 0 failures (0 unexpected) in 46.745 (47.009) seconds
** TEST SUCCEEDED **
```

A second run fired immediately after (to re-prove the check on the committed diff) hit a
**transient, environmental** failure — 2 of 990 tests in `WebhookServerTests`
(`testStartIfEnabledStartsWhenEnabled`, `testStartSetsRunningState`) failed with
`Network.NWError error 48 — Address already in use` (EADDRINUSE): both webhook tests bind
the same static `testPort`, and the prior run's `NWListener` had not yet released it. This
is port contention from two back-to-back full-gate runs, **not** a code regression — it is
in the webhook *server* binding path, which this change never touches (the change is a pure
`Double`-returning function in `SceneStateHelper`). In that run `SceneMenuItemTests` still
reported `Executed 18 tests, with 0 failures` and none of the three new tests errored.

Clean re-run after the port released — green:

```
	 Executed 990 tests, with 0 failures (0 unexpected) in 47.297 (47.685) seconds
** TEST SUCCEEDED **
```

Exit code `0`. Every pre-existing test green plus the three new ones; the EADDRINUSE flake
did not recur. The `com.apple.linkd.autoShortcut` (NSCocoaErrorDomain Code=4097) lines in
every run are benign App Intents connection noise from the headless test host, not failures.

---

## 6. Commit message & PR title

Both identical (Conventional Commits, scope-less `fix:`, no trailing period, no trailers):

```
fix: detect colour-setting scenes as active (hue/saturation tolerance)
```

Committed on the dispatched worktree branch `YuriNachos/r3-itsyhome-macos` (the worktree
the coordinator provisioned for this task; equivalent to the spec-suggested
`fix/157-scene-colour-tolerance`). The PR vehicle is this branch; the diff against `main`
contains only the four owned paths.

No `Co-Authored-By`, no `Signed-off-by`, no DCO — none appear in this repo's recent
history.

---

## 7. Anti-scope — explicitly left untouched

- `colorTemperature` was **not** added to the tolerance switch (no measured reproducer in
  #157; mireds/Kelvin semantics may warrant separate treatment). PR is `hue` + `saturation`
  only.
- `isActive(scene:bridge:)` is byte-for-byte unchanged — same comparison operator
  (`abs(current - target) >= tolerance(...)`), same nil/empty-actions handling, no new
  early return.
- `reverse(scene:bridge:)`, `offValue(for:)`, and `reversibleTypes` are unchanged.
- No webhook endpoint was touched; the bug lives entirely in `tolerance(for:)`.
- No other tolerance value was changed, no new characteristic cases beyond hue/saturation,
  and the switch was **not** refactored into a dictionary/lookup.
- The `Itsyhome` Catalyst app target, entitlements, and `project.yml` were not modified.
- The generated `*.xcodeproj` was never committed (`.gitignore:2 *.xcodeproj/`); it is
  regenerated locally by `xcodegen` before every build.
- Issue #150 (vertically-mirrored sparkline) and #148 (half-degree) were not touched —
  separate concerns, separate PRs.

---

## 8. Definition of Done — self-review

1. ✅ `tolerance(for:)` returns `1.0` for `hue` and `saturation`; the four original cases
   (`targetPosition`, `currentPosition`, `brightness`, `rotationSpeed`) still return `5.0`;
   `default` still `0.01`.
2. ✅ Three new tests exist in `macOSBridgeTests/SceneMenuItemTests.swift` and pass; the
   negative anchor `testColourSceneOutsideToleranceIsInactive` stays green.
3. ✅ Full GATE green (`** TEST SUCCEEDED **`, `Executed 990 tests, with 0 failures`).
4. ✅ `git diff --name-only main...HEAD` lists ONLY the owned paths:
   `macOSBridge/Webhook/SceneStateHelper.swift`,
   `macOSBridgeTests/SceneMenuItemTests.swift`, `CHANGELOG.md`,
   `.orca/reports/r3-itsyhome-macos.md`.
5. ✅ `CHANGELOG.md` has the new bullet under `## 3.0.0` (`#157, thanks @YuriNachos`).
6. ✅ This report exists with the diff, RED/GREEN/mutation/full-gate outputs, and the
   commit/PR title.

## Verification honesty

Only the headless `macOSBridgeTests` unit-test gate was exercised. **No** on-device run,
**no** HomeKit pairing, and **no** physical Hue bulb test was performed — the reproducer is
covered by the unit tests using the exact #157 values (hue `244.6013061341441` → device
`244`, delta `0.60`; saturation path identical at `89.4906…` → `89`, delta `0.49`).
