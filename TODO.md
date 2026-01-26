# All HomeKit

  ┌───────┬───────────────────────────────┬────────────────┐
  │  Hex  │            Service            │  We Support?   │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x40  │ Fan (v1)                      │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0xB7  │ Fan (v2)                      │ ✓ (just added) │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x41  │ Garage Door Opener            │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x43  │ Lightbulb                     │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x45  │ Lock Mechanism                │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x47  │ Outlet                        │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x49  │ Switch                        │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x4A  │ Thermostat                    │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x7E  │ Security System               │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x80  │ Contact Sensor                │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x82  │ Humidity Sensor               │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x85  │ Motion Sensor                 │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x8A  │ Temperature Sensor            │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x8C  │ Window Covering               │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0xBB  │ Air Purifier                  │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0xBC  │ Heater Cooler                 │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0xBD  │ Humidifier Dehumidifier       │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0xD0  │ Valve                         │ ✓              │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x7F  │ Carbon Monoxide Sensor        │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x81  │ Door                          │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x83  │ Leak Sensor                   │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x84  │ Light Sensor                  │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x86  │ Occupancy Sensor              │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x87  │ Smoke Sensor                  │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x89  │ Stateless Programmable Switch │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x8B  │ Window                        │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x8D  │ Air Quality Sensor            │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x97  │ Carbon Dioxide Sensor         │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0xB9  │ Slat                          │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0xCF  │ Irrigation System             │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0xD7  │ Faucet                        │ ❌             │
  ├───────┼───────────────────────────────┼────────────────┤
  │ 0x121 │ Doorbell                      │ ❌             │
  └───────┴───────────────────────────────┴────────────────┘
  

# Accessory fixes - HAP compliance

Fixing all accessory types to be fully HAP-compliant with proper controls.

## Characteristic value reference

| Characteristic | Format | Values | Writable |
|---------------|--------|--------|----------|
| OutletInUse | bool | false=not in use, true=in use | No (read-only) |
| TargetFanState | uint8 | 0=MANUAL, 1=AUTO | Yes |
| CurrentFanState | uint8 | 0=INACTIVE, 1=IDLE, 2=BLOWING_AIR | No |
| SwingMode | uint8 | 0=DISABLED, 1=ENABLED | Yes |
| RotationDirection | uint8 | 0=CLOCKWISE, 1=COUNTER_CLOCKWISE | Yes |
| RotationSpeed | float | 0-100 (percentage) | Yes |
| HorizontalTiltAngle | int | -90 to 90 degrees | Yes |
| VerticalTiltAngle | int | -90 to 90 degrees | Yes |
| WaterLevel | float | 0-100 (percentage) | No (read-only) |
| PositionState | uint8 | 0=GOING_TO_MIN, 1=GOING_TO_MAX, 2=STOPPED | No |

---

## 1. Outlet - Add "In Use" indicator

**Priority:** High (required by spec)

**Missing:** `OutletInUse` characteristic (read-only bool)

**Changes needed:**
- [ ] Add `outletInUseId: String?` to ServiceData
- [ ] Add `CharacteristicTypes.outletInUse` constant
- [ ] Extract characteristic in HomeKitManager.buildServiceData()
- [ ] Update SwitchMenuItem to show "In Use" indicator when outlet and in use
- [ ] Add mock outlet with outletInUseId to DebugMockAccessories

**Mock to verify:**
- Outlet shows power indicator/dot when something is drawing power
- Indicator updates when outletInUse value changes

---

## 2. Fan - Add auto mode and rotation direction

**Priority:** High (common feature)

**Missing:**
- `TargetFanState` (0=MANUAL, 1=AUTO) - writable
- `CurrentFanState` (0=INACTIVE, 1=IDLE, 2=BLOWING_AIR) - read-only
- `RotationDirection` (0=CLOCKWISE, 1=COUNTER_CLOCKWISE) - writable
- `SwingMode` (0=DISABLED, 1=ENABLED) - writable

**Changes needed:**
- [ ] Add to ServiceData: `targetFanStateId`, `currentFanStateId`, `rotationDirectionId`, `swingModeId`
- [ ] Add CharacteristicTypes constants
- [ ] Extract characteristics in HomeKitManager.buildServiceData()
- [ ] Create new FanMenuItem with:
  - Toggle switch (active)
  - Speed slider (rotationSpeed)
  - Auto/Manual mode toggle (targetFanState)
  - Direction button (rotationDirection) - shows as icon
  - Swing toggle (swingMode)
- [ ] Update mock fan in DebugMockAccessories

**Mock to verify:**
- Fan shows toggle + speed slider when on
- Auto/Manual mode buttons work
- Direction icon toggles (clockwise/counter-clockwise arrows)
- Swing toggle works

---

## 3. Window Covering - Add tilt angle controls

**Priority:** Medium (venetian blinds)

**Missing:**
- `CurrentHorizontalTiltAngle` / `TargetHorizontalTiltAngle` (-90 to 90)
- `CurrentVerticalTiltAngle` / `TargetVerticalTiltAngle` (-90 to 90)
- `PositionState` (0=GOING_TO_MIN, 1=GOING_TO_MAX, 2=STOPPED) - read-only

**Changes needed:**
- [ ] Add to ServiceData: `currentHorizontalTiltId`, `targetHorizontalTiltId`, `currentVerticalTiltId`, `targetVerticalTiltId`, `positionStateId`
- [ ] Add CharacteristicTypes constants
- [ ] Extract characteristics in HomeKitManager.buildServiceData()
- [ ] Update BlindsMenuItem:
  - Show tilt slider when tilt characteristics present
  - Position slider for open/close (existing)
  - Tilt slider for slat angle (-90 to 90, show as 0-100%)
- [ ] Add mock blinds with tilt to DebugMockAccessories

**Mock to verify:**
- Blinds with tilt show two controls: position + tilt
- Tilt slider adjusts slat angle
- Icon changes based on position/tilt

---

## 4. HeaterCooler/AC - Add swing mode

**Priority:** Medium (nice to have)

**Missing:** `SwingMode` (0=DISABLED, 1=ENABLED) - writable

**Changes needed:**
- [ ] Add `swingModeId: String?` to ServiceData
- [ ] Add CharacteristicTypes.swingMode constant
- [ ] Extract characteristic in HomeKitManager.buildServiceData()
- [ ] Update ACMenuItem:
  - Add swing toggle button in controls row
- [ ] Update mock AC in DebugMockAccessories

**Mock to verify:**
- AC shows swing toggle when characteristic present
- Toggle writes correct value (0/1)

---

## 5. Humidifier/Dehumidifier - Add water level and swing mode

**Priority:** Low (informational)

**Missing:**
- `WaterLevel` (0-100 percentage) - read-only
- `SwingMode` (0=DISABLED, 1=ENABLED) - writable

**Changes needed:**
- [ ] Add `waterLevelId: String?` to ServiceData
- [ ] Add CharacteristicTypes.waterLevel constant
- [ ] Extract characteristic in HomeKitManager.buildServiceData()
- [ ] Update HumidifierMenuItem:
  - Show water level indicator when present
  - Add swing toggle when present
- [ ] Add mock humidifier with water level to DebugMockAccessories

**Mock to verify:**
- Humidifier shows water level percentage
- Swing toggle works
- Updates when values change

---

## 6. Air Purifier - Add swing mode

**Priority:** Low (nice to have)

**Same as HeaterCooler swing mode** - reuse the same swingModeId characteristic

**Changes needed:**
- [ ] Update AirPurifierMenuItem to show swing toggle when present
- [ ] Update mock air purifier in DebugMockAccessories

---

## 7. Thermostat - Verify Auto mode thresholds

**Priority:** Medium (for Auto mode)

**Note:** Thermostat Auto mode may use:
- `targetTemperature` only (simpler thermostats)
- OR `coolingThresholdTemperature` + `heatingThresholdTemperature` (like AC)

**Changes needed:**
- [ ] Add coolingThresholdTemperatureId and heatingThresholdTemperatureId extraction for thermostats
- [ ] Check if thermostat has coolingThreshold/heatingThreshold
- [ ] If present in Auto mode, show two temp controls (like AC)
- [ ] If not present, show single targetTemperature control
- [ ] Update mock thermostat with thresholds option

**Mock to verify:**
- Thermostat in Auto mode shows appropriate temp control(s)

---

## Progress tracking

| # | Accessory | Status |
|---|-----------|--------|
| 1 | Outlet | ✅ Complete |
| 2 | Fan | ✅ Complete |
| 3 | Window Covering | ✅ Complete |
| 4 | HeaterCooler | ✅ Complete |
| 5 | Humidifier | ✅ Complete |
| 6 | Air Purifier | ✅ Complete |
| 7 | Thermostat | ⬜ Pending |

---

## Sources

- [Apple HomeKitADK - HAPServiceTypes.h](https://github.com/apple/HomeKitADK/blob/master/HAP/HAPServiceTypes.h)
- [Homebridge HAP-NodeJS Characteristics](https://developers.homebridge.io/HAP-NodeJS/classes/Characteristic.html)
- [Apple HMCharacteristicTypeWaterLevel](https://developer.apple.com/documentation/homekit/hmcharacteristictypewaterlevel)
- [Apple HMCharacteristicTypeTargetHorizontalTilt](https://developer.apple.com/documentation/homekit/hmcharacteristictypetargethorizontaltilt)
- [openHAB HomeKit Integration](https://www.openhab.org/addons/integrations/homekit/)

---

# Future: Missing controllable service types

These are controllable service types we don't yet support (excluding read-only sensors).

## Door (0x81)

**UUID:** `00000081-0000-1000-8000-0026BB765291`

**Description:** Motorized door control (not a contact sensor). Works like Window Covering with position-based control.

**Required characteristics:**
| Characteristic | UUID | Format | Values | Writable |
|---------------|------|--------|--------|----------|
| CurrentPosition | 0x6D | uint8 | 0-100 (percentage) | No |
| TargetPosition | 0x7C | uint8 | 0-100 (percentage) | Yes |
| PositionState | 0x72 | uint8 | 0=GOING_TO_MIN, 1=GOING_TO_MAX, 2=STOPPED | No |

**Optional characteristics:**
- HoldPosition (0x6F) - stops door at current position
- ObstructionDetected (0x24) - indicates blockage
- Name (0x23)

**Implementation notes:**
- Can reuse BlindMenuItem since same position-based control
- 0% = fully closed, 100% = fully open
- PositionState indicates if door is moving

---

## Window (0x8B)

**UUID:** `0000008B-0000-1000-8000-0026BB765291`

**Description:** Motorized window control. Identical to Door service in characteristics.

**Required characteristics:**
| Characteristic | UUID | Format | Values | Writable |
|---------------|------|--------|--------|----------|
| CurrentPosition | 0x6D | uint8 | 0-100 (percentage) | No |
| TargetPosition | 0x7C | uint8 | 0-100 (percentage) | Yes |
| PositionState | 0x72 | uint8 | 0=GOING_TO_MIN, 1=GOING_TO_MAX, 2=STOPPED | No |

**Optional characteristics:**
- HoldPosition (0x6F)
- ObstructionDetected (0x24)
- Name (0x23)

**Implementation notes:**
- Can reuse BlindMenuItem
- Same as Door - just different icon

---

## Slat (0xB9)

**UUID:** `000000B9-0000-1000-8000-0026BB765291`

**Description:** Slat/louver control for tilt angle (e.g., venetian blinds). Often linked to WindowCovering service.

**Required characteristics:**
| Characteristic | UUID | Format | Values | Writable |
|---------------|------|--------|--------|----------|
| SlatType | 0xC0 | uint8 | 0=HORIZONTAL, 1=VERTICAL | No |
| CurrentSlatState | 0xAA | uint8 | 0=FIXED, 1=JAMMED, 2=SWINGING | No |

**Optional characteristics:**
| Characteristic | UUID | Format | Values | Writable |
|---------------|------|--------|--------|----------|
| CurrentTiltAngle | 0xC1 | int | -90 to 90 degrees | No |
| TargetTiltAngle | 0xC2 | int | -90 to 90 degrees | Yes |
| SwingMode | 0xB6 | uint8 | 0=DISABLED, 1=ENABLED | Yes |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- Usually linked to WindowCovering service
- -90° = slats fully closed (user-facing edge higher)
- 0° = slats horizontal (open)
- +90° = slats fully closed (user-facing edge lower)
- SwingMode for oscillating slats (rare)
- Could be standalone or enhance BlindMenuItem

---

## Irrigation System (0xCF)

**UUID:** `000000CF-0000-1000-8000-0026BB765291`

**Description:** Master controller for irrigation with multiple linked Valve services. Provides top-level Active control across all valves.

**Required characteristics:**
| Characteristic | UUID | Format | Values | Writable |
|---------------|------|--------|--------|----------|
| Active | 0xB0 | uint8 | 0=INACTIVE, 1=ACTIVE | Yes |
| ProgramMode | 0xD1 | uint8 | 0=NONE, 1=SCHEDULED, 2=SCHEDULE_OVERRIDEN | No |
| InUse | 0xD2 | uint8 | 0=NOT_IN_USE, 1=IN_USE | No |

**Optional characteristics:**
| Characteristic | UUID | Format | Values | Writable |
|---------------|------|--------|--------|----------|
| RemainingDuration | 0xD4 | uint32 | 0-3600 seconds | No |
| StatusFault | 0x77 | uint8 | 0=NO_FAULT, 1=GENERAL_FAULT | No |
| Name | 0x23 | string | - | No |

**Linked services:**
- One or more Valve services (required)
- ServiceLabel for zone naming

**Implementation notes:**
- Active=1 enables the system, InUse=1 means water is flowing
- ProgramMode shows schedule status (read-only)
- RemainingDuration shows time left on current watering
- Apple Home doesn't allow scheduling water devices
- Each linked Valve has its own Active, InUse, SetDuration, RemainingDuration
- Could show as expandable with child Valve controls

---

## Faucet (0xD7)

**UUID:** `000000D7-0000-1000-8000-0026BB765291`

**Description:** Faucet or shower head control. Container for water outlets, optionally with temperature control.

**Required characteristics:**
| Characteristic | UUID | Format | Values | Writable |
|---------------|------|--------|--------|----------|
| Active | 0xB0 | uint8 | 0=INACTIVE, 1=ACTIVE | Yes |

**Optional characteristics:**
| Characteristic | UUID | Format | Values | Writable |
|---------------|------|--------|--------|----------|
| StatusFault | 0x77 | uint8 | 0=NO_FAULT, 1=GENERAL_FAULT | No |
| Name | 0x23 | string | - | No |

**Linked services:**
- HeaterCooler (for temperature control)
- One or more Valve services (for water outlets)

**Implementation notes:**
- Setting Active=0 turns off the faucet
- Similar to Valve but serves as container
- When linked to HeaterCooler, controls water temperature
- Could reuse ValveMenuItem with different icon
- Very similar to our existing Valve implementation

---

## Implementation priority

| Service | Priority | Complexity | Notes |
|---------|----------|------------|-------|
| Door | Low | Easy | Reuse BlindMenuItem |
| Window | Low | Easy | Reuse BlindMenuItem |
| Faucet | Low | Easy | Reuse ValveMenuItem |
| Slat | Medium | Medium | Add tilt slider, often linked to blinds |
| Irrigation System | Medium | High | Multi-valve with zones, expansion UI |

**Sources:**
- [Apple HomeKitADK - HAPServiceTypes.h](https://github.com/apple/HomeKitADK/blob/master/HAP/HAPServiceTypes.h)
- [NRCHKB Irrigation System](https://nrchkb.github.io/wiki/service/irrigation-system/)
- [esp-homekit-devices Wiki - Service Types](https://github.com/ravensystem/esp-homekit-devices/wiki/Service-Types)
- [Apple HMCharacteristicTypeTargetTilt](https://developer.apple.com/documentation/homekit/hmcharacteristictypetargettilt)
- [Homebridge HAP-NodeJS](https://developers.homebridge.io/HAP-NodeJS/classes/Service.html)


