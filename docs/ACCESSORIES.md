# HomeKit accessories reference

This document describes all HomeKit accessory types and their characteristics, organized by implementation status.

## Supported accessories

| Hex | Service | Status |
|-----|---------|--------|
| 0x43 | [Lightbulb](#lightbulb-0x43) | Supported |
| 0x49 | [Switch](#switch-0x49) | Supported |
| 0x47 | [Outlet](#outlet-0x47) | Supported |
| 0x4A | [Thermostat](#thermostat-0x4a) | Supported |
| 0xBC | [Heater Cooler](#heater-cooler-0xbc) | Supported |
| 0x45 | [Lock Mechanism](#lock-mechanism-0x45) | Supported |
| 0x8C | [Window Covering](#window-covering-0x8c) | Supported |
| 0x81 | [Door](#door-0x81) | Supported |
| 0x8B | [Window](#window-0x8b) | Supported |
| 0x8A | [Temperature Sensor](#temperature-sensor-0x8a) | Supported |
| 0x82 | [Humidity Sensor](#humidity-sensor-0x82) | Supported |
| 0x85 | [Motion Sensor](#motion-sensor-0x85) | Supported |
| 0x80 | [Contact Sensor](#contact-sensor-0x80) | Supported |
| 0x40 | [Fan (v1)](#fan-v1-0x40) | Supported |
| 0xB7 | [Fan (v2)](#fan-v2-0xb7) | Supported |
| 0x41 | [Garage Door Opener](#garage-door-opener-0x41) | Supported |
| 0xBD | [Humidifier Dehumidifier](#humidifier-dehumidifier-0xbd) | Supported |
| 0xBB | [Air Purifier](#air-purifier-0xbb) | Supported |
| 0xD0 | [Valve](#valve-0xd0) | Supported |
| 0xD7 | [Faucet](#faucet-0xd7) | Supported |
| 0xB9 | [Slat](#slat-0xb9) | Supported |
| 0x7E | [Security System](#security-system-0x7e) | Supported |

---

## Lightbulb (0x43)

**UUID:** `00000043-0000-1000-8000-0026BB765291`

**Description:** Controls a light source with optional brightness, color (hue/saturation), and color temperature.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| On | 0x25 | bool | true/false | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Brightness | 0x08 | int | 0-100 (percentage) | Yes |
| Hue | 0x13 | float | 0-360 (degrees) | Yes |
| Saturation | 0x2F | float | 0-100 (percentage) | Yes |
| ColorTemperature | 0xCE | uint32 | 140-500 (Mired) | Yes |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- Brightness only present on dimmable lights
- Hue and Saturation present together for RGB color lights
- ColorTemperature present for tunable white lights (may coexist with Hue/Saturation)
- ColorTemperature range varies by device (min/max Mired values)

---

## Switch (0x49)

**UUID:** `00000049-0000-1000-8000-0026BB765291`

**Description:** A simple on/off switch with no additional features.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| On | 0x25 | bool | true/false | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Name | 0x23 | string | - | No |

---

## Outlet (0x47)

**UUID:** `00000047-0000-1000-8000-0026BB765291`

**Description:** A smart outlet/plug that can report whether it's drawing power.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| On | 0x25 | bool | true/false | Yes |
| OutletInUse | 0x26 | bool | true/false | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Name | 0x23 | string | - | No |

**Implementation notes:**
- OutletInUse indicates whether the outlet is drawing power (device connected and consuming electricity)
- An outlet can be On but not InUse (switched on but nothing plugged in)

---

## Thermostat (0x4A)

**UUID:** `0000004A-0000-1000-8000-0026BB765291`

**Description:** Climate control device for heating and cooling with temperature setpoints.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentTemperature | 0x11 | float | 0-100 (Celsius) | No |
| TargetTemperature | 0x35 | float | 10-38 (Celsius) | Yes |
| CurrentHeatingCoolingState | 0x0F | uint8 | 0=OFF, 1=HEAT, 2=COOL | No |
| TargetHeatingCoolingState | 0x33 | uint8 | 0=OFF, 1=HEAT, 2=COOL, 3=AUTO | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CoolingThresholdTemperature | 0x0D | float | 10-35 (Celsius) | Yes |
| HeatingThresholdTemperature | 0x12 | float | 0-25 (Celsius) | Yes |
| TemperatureDisplayUnits | 0x36 | uint8 | 0=CELSIUS, 1=FAHRENHEIT | Yes |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- CurrentHeatingCoolingState reflects actual operation (read-only)
- TargetHeatingCoolingState sets desired mode
- When in AUTO mode, both threshold temperatures are used to define the temperature range
- When in HEAT or COOL mode, only TargetTemperature is used

---

## Heater Cooler (0xBC)

**UUID:** `000000BC-0000-1000-8000-0026BB765291`

**Description:** Air conditioning unit with heating and cooling capabilities.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Active | 0xB0 | uint8 | 0=INACTIVE, 1=ACTIVE | Yes |
| CurrentTemperature | 0x11 | float | 0-100 (Celsius) | No |
| CurrentHeaterCoolerState | 0xB1 | uint8 | 0=INACTIVE, 1=IDLE, 2=HEATING, 3=COOLING | No |
| TargetHeaterCoolerState | 0xB2 | uint8 | 0=AUTO, 1=HEAT, 2=COOL | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CoolingThresholdTemperature | 0x0D | float | 10-35 (Celsius) | Yes |
| HeatingThresholdTemperature | 0x12 | float | 0-25 (Celsius) | Yes |
| RotationSpeed | 0x29 | float | 0-100 (percentage) | Yes |
| SwingMode | 0xB6 | uint8 | 0=DISABLED, 1=ENABLED | Yes |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- Active controls power on/off
- CurrentHeaterCoolerState shows actual operation including IDLE when target reached
- In AUTO mode, both threshold temperatures define the comfort range
- In HEAT or COOL mode, only the corresponding threshold is used

---

## Lock Mechanism (0x45)

**UUID:** `00000045-0000-1000-8000-0026BB765291`

**Description:** Door lock that can be locked and unlocked.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| LockCurrentState | 0x1D | uint8 | 0=UNSECURED, 1=SECURED, 2=JAMMED, 3=UNKNOWN | No |
| LockTargetState | 0x1E | uint8 | 0=UNSECURED, 1=SECURED | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Name | 0x23 | string | - | No |

**Implementation notes:**
- LockCurrentState may differ from LockTargetState during transition or if jammed
- JAMMED state indicates a mechanical issue preventing lock/unlock

---

## Window Covering (0x8C)

**UUID:** `0000008C-0000-1000-8000-0026BB765291`

**Description:** Motorized blinds, shades, or shutters with position and optional tilt control.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentPosition | 0x6D | uint8 | 0-100 (percentage) | No |
| TargetPosition | 0x7C | uint8 | 0-100 (percentage) | Yes |
| PositionState | 0x72 | uint8 | 0=GOING_TO_MIN, 1=GOING_TO_MAX, 2=STOPPED | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentHorizontalTiltAngle | 0x6C | int | -90 to 90 (degrees) | No |
| TargetHorizontalTiltAngle | 0x7B | int | -90 to 90 (degrees) | Yes |
| CurrentVerticalTiltAngle | 0x6E | int | -90 to 90 (degrees) | No |
| TargetVerticalTiltAngle | 0x7D | int | -90 to 90 (degrees) | Yes |
| ObstructionDetected | 0x24 | bool | true/false | No |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- Position 0 = fully closed, 100 = fully open
- Tilt angle controls slat angle (horizontal or vertical depending on blind type)
- Only one tilt direction (horizontal or vertical) is typically present

---

## Door (0x81)

**UUID:** `00000081-0000-1000-8000-0026BB765291`

**Description:** Motorized door with position control.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentPosition | 0x6D | uint8 | 0-100 (percentage) | No |
| TargetPosition | 0x7C | uint8 | 0-100 (percentage) | Yes |
| PositionState | 0x72 | uint8 | 0=GOING_TO_MIN, 1=GOING_TO_MAX, 2=STOPPED | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| ObstructionDetected | 0x24 | bool | true/false | No |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- Position 0 = fully closed, 100 = fully open
- Uses same characteristics as Window Covering but without tilt

---

## Window (0x8B)

**UUID:** `0000008B-0000-1000-8000-0026BB765291`

**Description:** Motorized window with position control.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentPosition | 0x6D | uint8 | 0-100 (percentage) | No |
| TargetPosition | 0x7C | uint8 | 0-100 (percentage) | Yes |
| PositionState | 0x72 | uint8 | 0=GOING_TO_MIN, 1=GOING_TO_MAX, 2=STOPPED | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| ObstructionDetected | 0x24 | bool | true/false | No |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- Position 0 = fully closed, 100 = fully open
- Identical to Door service in characteristics

---

## Temperature Sensor (0x8A)

**UUID:** `0000008A-0000-1000-8000-0026BB765291`

**Description:** Reports ambient temperature.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentTemperature | 0x11 | float | 0-100 (Celsius) | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| StatusActive | 0x75 | bool | true/false | No |
| StatusFault | 0x77 | uint8 | 0=NO_FAULT, 1=GENERAL_FAULT | No |
| StatusLowBattery | 0x79 | uint8 | 0=NORMAL, 1=LOW | No |
| StatusTampered | 0x7A | uint8 | 0=NOT_TAMPERED, 1=TAMPERED | No |
| Name | 0x23 | string | - | No |

---

## Humidity Sensor (0x82)

**UUID:** `00000082-0000-1000-8000-0026BB765291`

**Description:** Reports ambient relative humidity.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentRelativeHumidity | 0x10 | float | 0-100 (percentage) | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| StatusActive | 0x75 | bool | true/false | No |
| StatusFault | 0x77 | uint8 | 0=NO_FAULT, 1=GENERAL_FAULT | No |
| StatusLowBattery | 0x79 | uint8 | 0=NORMAL, 1=LOW | No |
| StatusTampered | 0x7A | uint8 | 0=NOT_TAMPERED, 1=TAMPERED | No |
| Name | 0x23 | string | - | No |

---

## Motion Sensor (0x85)

**UUID:** `00000085-0000-1000-8000-0026BB765291`

**Description:** Detects motion/movement.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| MotionDetected | 0x22 | bool | true/false | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| StatusActive | 0x75 | bool | true/false | No |
| StatusFault | 0x77 | uint8 | 0=NO_FAULT, 1=GENERAL_FAULT | No |
| StatusLowBattery | 0x79 | uint8 | 0=NORMAL, 1=LOW | No |
| StatusTampered | 0x7A | uint8 | 0=NOT_TAMPERED, 1=TAMPERED | No |
| Name | 0x23 | string | - | No |

---

## Contact Sensor (0x80)

**UUID:** `00000080-0000-1000-8000-0026BB765291`

**Description:** Detects whether two surfaces are in contact (door/window open/closed).

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| ContactSensorState | 0x6A | uint8 | 0=DETECTED (closed), 1=NOT_DETECTED (open) | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| StatusActive | 0x75 | bool | true/false | No |
| StatusFault | 0x77 | uint8 | 0=NO_FAULT, 1=GENERAL_FAULT | No |
| StatusLowBattery | 0x79 | uint8 | 0=NORMAL, 1=LOW | No |
| StatusTampered | 0x7A | uint8 | 0=NOT_TAMPERED, 1=TAMPERED | No |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- DETECTED (0) means contact is detected, typically door/window closed
- NOT_DETECTED (1) means no contact, typically door/window open

---

## Fan (v1) (0x40)

**UUID:** `00000040-0000-1000-8000-0026BB765291`

**Description:** Basic fan with on/off and optional speed control.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| On | 0x25 | bool | true/false | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| RotationSpeed | 0x29 | float | 0-100 (percentage) | Yes |
| RotationDirection | 0x28 | int | 0=CLOCKWISE, 1=COUNTER_CLOCKWISE | Yes |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- Legacy fan service, Fan v2 is preferred for new implementations
- RotationSpeed range may vary by device

---

## Fan (v2) (0xB7)

**UUID:** `000000B7-0000-1000-8000-0026BB765291`

**Description:** Advanced fan with active state, speed, direction, and swing mode.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Active | 0xB0 | uint8 | 0=INACTIVE, 1=ACTIVE | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentFanState | 0xAF | uint8 | 0=INACTIVE, 1=IDLE, 2=BLOWING_AIR | No |
| TargetFanState | 0xBF | uint8 | 0=MANUAL, 1=AUTO | Yes |
| RotationSpeed | 0x29 | float | 0-100 (percentage) | Yes |
| RotationDirection | 0x28 | int | 0=CLOCKWISE, 1=COUNTER_CLOCKWISE | Yes |
| SwingMode | 0xB6 | uint8 | 0=DISABLED, 1=ENABLED | Yes |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- Active controls power on/off
- CurrentFanState shows actual operation (IDLE when target speed reached but not blowing)
- TargetFanState allows AUTO mode where fan adjusts speed automatically
- SwingMode controls oscillation

---

## Garage Door Opener (0x41)

**UUID:** `00000041-0000-1000-8000-0026BB765291`

**Description:** Motorized garage door with open/close control.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentDoorState | 0x0E | uint8 | 0=OPEN, 1=CLOSED, 2=OPENING, 3=CLOSING, 4=STOPPED | No |
| TargetDoorState | 0x32 | uint8 | 0=OPEN, 1=CLOSED | Yes |
| ObstructionDetected | 0x24 | bool | true/false | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| LockCurrentState | 0x1D | uint8 | 0=UNSECURED, 1=SECURED, 2=JAMMED, 3=UNKNOWN | No |
| LockTargetState | 0x1E | uint8 | 0=UNSECURED, 1=SECURED | Yes |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- CurrentDoorState may be OPENING/CLOSING during transition
- STOPPED indicates door stopped mid-travel (possibly due to obstruction)
- ObstructionDetected triggers safety stop

---

## Humidifier Dehumidifier (0xBD)

**UUID:** `000000BD-0000-1000-8000-0026BB765291`

**Description:** Device that can add or remove moisture from air.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Active | 0xB0 | uint8 | 0=INACTIVE, 1=ACTIVE | Yes |
| CurrentRelativeHumidity | 0x10 | float | 0-100 (percentage) | No |
| CurrentHumidifierDehumidifierState | 0xB3 | uint8 | 0=INACTIVE, 1=IDLE, 2=HUMIDIFYING, 3=DEHUMIDIFYING | No |
| TargetHumidifierDehumidifierState | 0xB4 | uint8 | 0=AUTO, 1=HUMIDIFIER, 2=DEHUMIDIFIER | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| RelativeHumidityHumidifierThreshold | 0xCA | float | 0-100 (percentage) | Yes |
| RelativeHumidityDehumidifierThreshold | 0xC9 | float | 0-100 (percentage) | Yes |
| RotationSpeed | 0x29 | float | 0-100 (percentage) | Yes |
| SwingMode | 0xB6 | uint8 | 0=DISABLED, 1=ENABLED | Yes |
| WaterLevel | 0xB5 | float | 0-100 (percentage) | No |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- In HUMIDIFIER mode, runs until HumidifierThreshold is reached
- In DEHUMIDIFIER mode, runs until DehumidifierThreshold is reached
- In AUTO mode, maintains humidity between both thresholds
- WaterLevel indicates tank level (low = needs refill for humidifier, needs emptying for dehumidifier)

---

## Air Purifier (0xBB)

**UUID:** `000000BB-0000-1000-8000-0026BB765291`

**Description:** Air filtration device.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Active | 0xB0 | uint8 | 0=INACTIVE, 1=ACTIVE | Yes |
| CurrentAirPurifierState | 0xA9 | uint8 | 0=INACTIVE, 1=IDLE, 2=PURIFYING_AIR | No |
| TargetAirPurifierState | 0xA8 | uint8 | 0=MANUAL, 1=AUTO | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| RotationSpeed | 0x29 | float | 0-100 (percentage) | Yes |
| SwingMode | 0xB6 | uint8 | 0=DISABLED, 1=ENABLED | Yes |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- In AUTO mode, purifier adjusts speed based on air quality sensors
- In MANUAL mode, user controls speed directly
- May have linked FilterMaintenance service for filter status

---

## Valve (0xD0)

**UUID:** `000000D0-0000-1000-8000-0026BB765291`

**Description:** Water valve for irrigation or other water control applications.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Active | 0xB0 | uint8 | 0=INACTIVE, 1=ACTIVE | Yes |
| InUse | 0xD2 | uint8 | 0=NOT_IN_USE, 1=IN_USE | No |
| ValveType | 0xD5 | uint8 | 0=GENERIC, 1=IRRIGATION, 2=SHOWER_HEAD, 3=WATER_FAUCET | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| SetDuration | 0xD3 | uint32 | 0-3600 (seconds) | Yes |
| RemainingDuration | 0xD4 | uint32 | 0-3600 (seconds) | No |
| IsConfigured | 0xD6 | uint8 | 0=NOT_CONFIGURED, 1=CONFIGURED | No |
| StatusFault | 0x77 | uint8 | 0=NO_FAULT, 1=GENERAL_FAULT | No |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- Active=1 opens the valve, InUse=1 means water is actually flowing
- SetDuration allows timed operation
- RemainingDuration counts down during timed operation

---

## Faucet (0xD7)

**UUID:** `000000D7-0000-1000-8000-0026BB765291`

**Description:** Water faucet control.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Active | 0xB0 | uint8 | 0=INACTIVE, 1=ACTIVE | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| StatusFault | 0x77 | uint8 | 0=NO_FAULT, 1=GENERAL_FAULT | No |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- May have linked Valve services for hot/cold water control
- Simpler than Valve service, primarily for basic on/off control

---

## Slat (0xB9)

**UUID:** `000000B9-0000-1000-8000-0026BB765291`

**Description:** Adjustable slats/louvers for light and airflow control.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentSlatState | 0xAA | uint8 | 0=FIXED, 1=JAMMED, 2=SWINGING | No |
| SlatType | 0xC0 | uint8 | 0=HORIZONTAL, 1=VERTICAL | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| CurrentTiltAngle | 0xC1 | int | -90 to 90 (degrees) | No |
| TargetTiltAngle | 0xC2 | int | -90 to 90 (degrees) | Yes |
| SwingMode | 0xB6 | uint8 | 0=DISABLED, 1=ENABLED | Yes |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- SlatType indicates orientation (horizontal slats like blinds, or vertical like louvers)
- Tilt angle of 0 is typically neutral/closed position
- SwingMode allows automatic oscillation

---

## Security System (0x7E)

**UUID:** `0000007E-0000-1000-8000-0026BB765291`

**Description:** Home security alarm system.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| SecuritySystemCurrentState | 0x66 | uint8 | 0=STAY_ARM, 1=AWAY_ARM, 2=NIGHT_ARM, 3=DISARMED, 4=ALARM_TRIGGERED | No |
| SecuritySystemTargetState | 0x67 | uint8 | 0=STAY_ARM, 1=AWAY_ARM, 2=NIGHT_ARM, 3=DISARM | Yes |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| StatusFault | 0x77 | uint8 | 0=NO_FAULT, 1=GENERAL_FAULT | No |
| StatusTampered | 0x7A | uint8 | 0=NOT_TAMPERED, 1=TAMPERED | No |
| SecuritySystemAlarmType | 0x8E | uint8 | 0=UNKNOWN, 1=INTRUSION | No |
| Name | 0x23 | string | - | No |

**Implementation notes:**
- STAY_ARM: Armed for when occupants are home (perimeter only)
- AWAY_ARM: Fully armed when home is empty
- NIGHT_ARM: Armed for nighttime (partial)
- ALARM_TRIGGERED (4) is read-only and indicates active alarm

---

## Future implementation

The following accessories are not yet supported but may be added in future versions.

| Hex | Service |
|-----|---------|
| 0x7F | Carbon Monoxide Sensor |
| 0x83 | Leak Sensor |
| 0x84 | Light Sensor |
| 0x86 | Occupancy Sensor |
| 0x87 | Smoke Sensor |
| 0x89 | Stateless Programmable Switch |
| 0x8D | Air Quality Sensor |
| 0x97 | Carbon Dioxide Sensor |
| 0xCF | Irrigation System |
| 0x121 | Doorbell |

---

### Irrigation System (0xCF)

**UUID:** `000000CF-0000-1000-8000-0026BB765291`

**Description:** Master controller for irrigation with multiple linked Valve services. Provides top-level Active control across all valves.

**Required characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
| Active | 0xB0 | uint8 | 0=INACTIVE, 1=ACTIVE | Yes |
| ProgramMode | 0xD1 | uint8 | 0=NONE, 1=SCHEDULED, 2=SCHEDULE_OVERRIDEN | No |
| InUse | 0xD2 | uint8 | 0=NOT_IN_USE, 1=IN_USE | No |

**Optional characteristics:**

| Characteristic | UUID | Format | Values | Writable |
|----------------|------|--------|--------|----------|
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

## Sources

- [Apple HomeKitADK - HAPServiceTypes.h](https://github.com/apple/HomeKitADK/blob/master/HAP/HAPServiceTypes.h)
- [Apple HomeKitADK - HAPCharacteristicTypes.h](https://github.com/apple/HomeKitADK/blob/master/HAP/HAPCharacteristicTypes.h)
- [NRCHKB Wiki - Service Types](https://nrchkb.github.io/wiki/service/)
- [esp-homekit-devices Wiki - Service Types](https://github.com/ravensystem/esp-homekit-devices/wiki/Service-Types)
- [Apple HMCharacteristicType Documentation](https://developer.apple.com/documentation/homekit/hmcharacteristictype)
- [Homebridge HAP-NodeJS](https://developers.homebridge.io/HAP-NodeJS/classes/Service.html)
