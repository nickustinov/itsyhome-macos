# Plan: real-time HomeKit characteristic notifications

## Problem

When a user toggles an accessory (e.g. a light) from the Home app, our menu bar UI does not update until the user clicks the menu bar icon, which triggers `refreshCharacteristics()` → `readValue()` on each visible characteristic. The app should reflect state changes in real time.

## Root cause

HomeKit delivers real-time updates via `HMAccessoryDelegate.accessory(_:service:didUpdateValueFor:)`, but only for characteristics where `enableNotification(true)` has been called. Currently, only doorbell `ProgrammableSwitchEvent` characteristics are subscribed (`HomeKitManager+Doorbell.swift:39`). All other characteristics (power state, brightness, temperature, lock state, etc.) are never subscribed – so HomeKit never pushes their changes.

The delegate infrastructure is already fully wired:

1. `accessory.delegate = self` is set for every accessory (`HomeKitManager+DataFetching.swift:107-109`)
2. `accessory(_:service:didUpdateValueFor:)` routes updates to macOS (`HomeKitManager.swift:172-180`)
3. `MacOSController.updateMenuItems(for:value:isLocalChange:)` propagates to menu items, pinned items, and SSE (`MacOSController+MenuUpdates.swift:14-26`)

The only missing piece is step 0: telling HomeKit we want notifications.

## Implementation

### Step 1: Add `subscribeToCharacteristicNotifications()` method

**File:** `Itsyhome/iOS/HomeKitManager+DataFetching.swift`

Add a new method after `subscribeToDoorbellEvents()` is called (around line 112):

```swift
func subscribeToCharacteristicNotifications() {
    guard let home = selectedHome else { return }

    var subscribed = 0
    for accessory in home.accessories {
        for service in accessory.services {
            for characteristic in service.characteristics {
                guard characteristic.properties.contains(
                    HMCharacteristicPropertySupportsEventNotification
                ) else { continue }

                characteristic.enableNotification(true) { error in
                    if let error = error {
                        logger.error("enableNotification failed for \(characteristic.characteristicType): \(error.localizedDescription)")
                    }
                }
                subscribed += 1
            }
        }
    }
    logger.info("Subscribed to notifications for \(subscribed) characteristics")
}
```

### Step 2: Call from `fetchDataAndReloadMenu()`

**File:** `Itsyhome/iOS/HomeKitManager+DataFetching.swift`, line ~112

Add the call right after `subscribeToDoorbellEvents()`:

```swift
// Subscribe to doorbell events
subscribeToDoorbellEvents()

// Subscribe to all characteristic notifications for real-time updates
subscribeToCharacteristicNotifications()
```

### Step 3: Subscribe for newly added accessories

**File:** `Itsyhome/iOS/HomeKitManager.swift`, line 139–142

The `home(_:didAdd:)` delegate already sets the delegate and reloads. Since `fetchDataAndReloadMenu()` now calls `subscribeToCharacteristicNotifications()`, new accessories will be subscribed automatically. No additional change needed here.

### Step 4: Re-read values on reachability restore

**File:** `Itsyhome/iOS/HomeKitManager.swift`, line 168–170

When an accessory becomes reachable again, we may have missed updates while it was unreachable. Enhance `accessoryDidUpdateReachability`:

```swift
func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
    macOSDelegate?.setReachability(
        accessoryIdentifier: accessory.uniqueIdentifier,
        isReachable: accessory.isReachable
    )

    // Re-read all characteristic values when accessory becomes reachable,
    // since we may have missed updates while it was unreachable
    if accessory.isReachable {
        for service in accessory.services {
            for characteristic in service.characteristics {
                characteristic.readValue { error in
                    if error == nil, let value = characteristic.value {
                        self.macOSDelegate?.updateCharacteristic(
                            identifier: characteristic.uniqueIdentifier,
                            value: value
                        )
                    }
                }
            }
        }
    }
}
```

## Files changed

| File | Change |
|------|--------|
| `Itsyhome/iOS/HomeKitManager+DataFetching.swift` | Add `subscribeToCharacteristicNotifications()`, call it from `fetchDataAndReloadMenu()` |
| `Itsyhome/iOS/HomeKitManager.swift` | Enhance `accessoryDidUpdateReachability` to re-read values on reconnect |

## Notes

- `enableNotification(true)` persists only while the app process is alive. Resubscription happens automatically on next `fetchDataAndReloadMenu()` call (app launch, home change, accessory added/removed).
- Not all characteristics support event notifications – the `HMCharacteristicPropertySupportsEventNotification` check handles this.
- The doorbell subscription in `HomeKitManager+Doorbell.swift` can remain as-is since the generic subscription will also cover it (double-subscribing is harmless), and the doorbell code serves as documentation of that specific feature.
