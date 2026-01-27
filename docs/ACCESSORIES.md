# HomeKit accessories reference

This document describes HomeKit accessory types and their characteristics based on the [Apple HomeKit Accessory Protocol (HAP) specification](https://github.com/apple/HomeKitADK).

**Sources:**
- [Apple HomeKitADK - HAPServiceTypes.h](https://github.com/apple/HomeKitADK/blob/master/HAP/HAPServiceTypes.h) - Service definitions with required/optional characteristics
- [esp-homekit - characteristics.h](https://github.com/maximkulkin/esp-homekit/blob/master/include/homekit/characteristics.h) - Characteristic properties (format, permissions, ranges)

---

## Supported accessories

| Hex | Service | Itsyhome |
|-----|---------|----------|
| 0x43 | [Lightbulb](#lightbulb-0x43) | ✓ |
| 0x49 | [Switch](#switch-0x49) | ✓ |
| 0x47 | [Outlet](#outlet-0x47) | ✓ |
| 0x4A | [Thermostat](#thermostat-0x4a) | ✓ |
| 0xBC | [Heater Cooler](#heater-cooler-0xbc) | ✓ |
| 0x45 | [Lock Mechanism](#lock-mechanism-0x45) | ✓ |
| 0x8C | [Window Covering](#window-covering-0x8c) | ✓ |
| 0x81 | [Door](#door-0x81) | ✓ |
| 0x8B | [Window](#window-0x8b) | ✓ |
| 0x8A | [Temperature Sensor](#temperature-sensor-0x8a) | ✓ |
| 0x82 | [Humidity Sensor](#humidity-sensor-0x82) | ✓ |
| 0x85 | [Motion Sensor](#motion-sensor-0x85) | ✓ |
| 0x80 | [Contact Sensor](#contact-sensor-0x80) | ✓ |
| 0x40 | [Fan (v1)](#fan-v1-0x40) | ✓ |
| 0xB7 | [Fan (v2)](#fan-v2-0xb7) | ✓ |
| 0x41 | [Garage Door Opener](#garage-door-opener-0x41) | ✓ |
| 0xBD | [Humidifier Dehumidifier](#humidifier-dehumidifier-0xbd) | ✓ |
| 0xBB | [Air Purifier](#air-purifier-0xbb) | ✓ |
| 0xD0 | [Valve](#valve-0xd0) | ✓ |
| 0xD7 | [Faucet](#faucet-0xd7) | ✓ |
| 0xB9 | [Slat](#slat-0xb9) | ✓ |
| 0x7E | [Security System](#security-system-0x7e) | ✓ |

---

## Lightbulb (0x43)

**UUID:** `00000043-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| On | 0x25 | bool | read, write, notify | — | ✓ read/write |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Brightness | 0x08 | int | read, write, notify | 0-100 | ✓ read/write |
| Hue | 0x13 | float | read, write, notify | 0-360 | ✓ read/write |
| Saturation | 0x2F | float | read, write, notify | 0-100 | ✓ read/write |
| Color Temperature | 0xCE | uint32 | read, write, notify | 50-400 | ✓ read/write |

---

## Switch (0x49)

**UUID:** `00000049-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| On | 0x25 | bool | read, write, notify | — | ✓ read/write |

---

## Outlet (0x47)

**UUID:** `00000047-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| On | 0x25 | bool | read, write, notify | — | ✓ read/write |
| Outlet In Use | 0x26 | bool | read, notify | — | ✓ read |

---

## Thermostat (0x4A)

**UUID:** `0000004A-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Current Heating Cooling State | 0x0F | uint8 | read, notify | 0-2 | 0=OFF, 1=HEAT, 2=COOL | ✓ read |
| Target Heating Cooling State | 0x33 | uint8 | read, write, notify | 0-3 | 0=OFF, 1=HEAT, 2=COOL, 3=AUTO | ✓ read/write |
| Current Temperature | 0x11 | float | read, notify | 0-100 | Celsius | ✓ read |
| Target Temperature | 0x35 | float | read, write, notify | 10-38 | Celsius | ✓ read/write |
| Temperature Display Units | 0x36 | uint8 | read, write, notify | 0-1 | 0=CELSIUS, 1=FAHRENHEIT | ✗ |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Cooling Threshold Temperature | 0x0D | float | read, write, notify | 10-35 | ✓ read/write |
| Heating Threshold Temperature | 0x12 | float | read, write, notify | 0-25 | ✓ read/write |
| Current Relative Humidity | 0x10 | float | read, notify | 0-100 | ✗ |
| Target Relative Humidity | 0x34 | float | read, write, notify | 0-100 | ✗ |

---

## Heater Cooler (0xBC)

**UUID:** `000000BC-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Active | 0xB0 | uint8 | read, write, notify | 0-1 | 0=INACTIVE, 1=ACTIVE | ✓ read/write |
| Current Temperature | 0x11 | float | read, notify | 0-100 | Celsius | ✓ read |
| Current Heater Cooler State | 0xB1 | uint8 | read, notify | 0-3 | 0=INACTIVE, 1=IDLE, 2=HEATING, 3=COOLING | ✓ read |
| Target Heater Cooler State | 0xB2 | uint8 | read, write, notify | 0-2 | 0=AUTO, 1=HEAT, 2=COOL | ✓ read/write |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Cooling Threshold Temperature | 0x0D | float | read, write, notify | 10-35 | ✓ read/write |
| Heating Threshold Temperature | 0x12 | float | read, write, notify | 0-25 | ✓ read/write |
| Rotation Speed | 0x29 | float | read, write, notify | 0-100 | ✗ |
| Swing Mode | 0xB6 | uint8 | read, write, notify | 0-1 | ✓ read/write |
| Temperature Display Units | 0x36 | uint8 | read, write, notify | 0-1 | ✗ |
| Lock Physical Controls | 0xA7 | uint8 | read, write, notify | 0-1 | ✗ |

---

## Lock Mechanism (0x45)

**UUID:** `00000045-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Lock Current State | 0x1D | uint8 | read, notify | 0-3 | 0=UNSECURED, 1=SECURED, 2=JAMMED, 3=UNKNOWN | ✓ read |
| Lock Target State | 0x1E | uint8 | read, write, notify | 0-1 | 0=UNSECURED, 1=SECURED | ✓ read/write |

---

## Window Covering (0x8C)

**UUID:** `0000008C-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Current Position | 0x6D | uint8 | read, notify | 0-100 | percentage | ✓ read |
| Target Position | 0x7C | uint8 | read, write, notify | 0-100 | percentage | ✓ read/write |
| Position State | 0x72 | uint8 | read, notify | 0-2 | 0=DECREASING, 1=INCREASING, 2=STOPPED | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Current Horizontal Tilt Angle | 0x6C | int | read, notify | -90 to 90 | ✓ read |
| Target Horizontal Tilt Angle | 0x7B | int | read, write, notify | -90 to 90 | ✓ read/write |
| Current Vertical Tilt Angle | 0x6E | int | read, notify | -90 to 90 | ✓ read |
| Target Vertical Tilt Angle | 0x7D | int | read, write, notify | -90 to 90 | ✓ read/write |
| Hold Position | 0x6F | bool | write | — | ✗ |
| Obstruction Detected | 0x24 | bool | read, notify | — | ✗ |

---

## Door (0x81)

**UUID:** `00000081-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Current Position | 0x6D | uint8 | read, notify | 0-100 | percentage | ✓ read |
| Target Position | 0x7C | uint8 | read, write, notify | 0-100 | percentage | ✓ read/write |
| Position State | 0x72 | uint8 | read, notify | 0-2 | 0=DECREASING, 1=INCREASING, 2=STOPPED | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Hold Position | 0x6F | bool | write | — | ✗ |
| Obstruction Detected | 0x24 | bool | read, notify | — | ✗ |

---

## Window (0x8B)

**UUID:** `0000008B-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Current Position | 0x6D | uint8 | read, notify | 0-100 | percentage | ✓ read |
| Target Position | 0x7C | uint8 | read, write, notify | 0-100 | percentage | ✓ read/write |
| Position State | 0x72 | uint8 | read, notify | 0-2 | 0=DECREASING, 1=INCREASING, 2=STOPPED | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Hold Position | 0x6F | bool | write | — | ✗ |
| Obstruction Detected | 0x24 | bool | read, notify | — | ✗ |

---

## Temperature Sensor (0x8A)

**UUID:** `0000008A-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Current Temperature | 0x11 | float | read, notify | 0-100 | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Status Active | 0x75 | bool | read, notify | — | ✗ |
| Status Fault | 0x77 | uint8 | read, notify | 0-1 | ✗ |
| Status Low Battery | 0x79 | uint8 | read, notify | 0-1 | ✗ |
| Status Tampered | 0x7A | uint8 | read, notify | 0-1 | ✗ |

---

## Humidity Sensor (0x82)

**UUID:** `00000082-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Current Relative Humidity | 0x10 | float | read, notify | 0-100 | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Status Active | 0x75 | bool | read, notify | — | ✗ |
| Status Fault | 0x77 | uint8 | read, notify | 0-1 | ✗ |
| Status Low Battery | 0x79 | uint8 | read, notify | 0-1 | ✗ |
| Status Tampered | 0x7A | uint8 | read, notify | 0-1 | ✗ |

---

## Motion Sensor (0x85)

**UUID:** `00000085-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Motion Detected | 0x22 | bool | read, notify | — | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Status Active | 0x75 | bool | read, notify | — | ✗ |
| Status Fault | 0x77 | uint8 | read, notify | 0-1 | ✗ |
| Status Low Battery | 0x79 | uint8 | read, notify | 0-1 | ✗ |
| Status Tampered | 0x7A | uint8 | read, notify | 0-1 | ✗ |

---

## Contact Sensor (0x80)

**UUID:** `00000080-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Contact Sensor State | 0x6A | uint8 | read, notify | 0-1 | 0=DETECTED, 1=NOT_DETECTED | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Status Active | 0x75 | bool | read, notify | — | ✗ |
| Status Fault | 0x77 | uint8 | read, notify | 0-1 | ✗ |
| Status Low Battery | 0x79 | uint8 | read, notify | 0-1 | ✗ |
| Status Tampered | 0x7A | uint8 | read, notify | 0-1 | ✗ |

---

## Fan (v1) (0x40)

**UUID:** `00000040-0000-1000-8000-0026BB765291`

Note: This is the legacy Fan service. Fan v2 (0xB7) is preferred.

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| On | 0x25 | bool | read, write, notify | — | ✓ read/write |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Rotation Speed | 0x29 | float | read, write, notify | 0-100 | ✓ read/write |
| Rotation Direction | 0x28 | int | read, write, notify | 0-1 | ✓ read/write |

---

## Fan (v2) (0xB7)

**UUID:** `000000B7-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Active | 0xB0 | uint8 | read, write, notify | 0-1 | 0=INACTIVE, 1=ACTIVE | ✓ read/write |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Current Fan State | 0xAF | uint8 | read, notify | 0-2 | 0=INACTIVE, 1=IDLE, 2=BLOWING_AIR | ✓ read |
| Target Fan State | 0xBF | uint8 | read, write, notify | 0-1 | 0=MANUAL, 1=AUTO | ✓ read/write |
| Rotation Speed | 0x29 | float | read, write, notify | 0-100 | — | ✓ read/write |
| Rotation Direction | 0x28 | int | read, write, notify | 0-1 | 0=CLOCKWISE, 1=COUNTER_CLOCKWISE | ✓ read/write |
| Swing Mode | 0xB6 | uint8 | read, write, notify | 0-1 | 0=DISABLED, 1=ENABLED | ✓ read/write |
| Lock Physical Controls | 0xA7 | uint8 | read, write, notify | 0-1 | — | ✗ |

---

## Garage Door Opener (0x41)

**UUID:** `00000041-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Current Door State | 0x0E | uint8 | read, notify | 0-4 | 0=OPEN, 1=CLOSED, 2=OPENING, 3=CLOSING, 4=STOPPED | ✓ read |
| Target Door State | 0x32 | uint8 | read, write, notify | 0-1 | 0=OPEN, 1=CLOSED | ✓ read/write |
| Obstruction Detected | 0x24 | bool | read, notify | — | — | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Lock Current State | 0x1D | uint8 | read, notify | 0-3 | ✗ |
| Lock Target State | 0x1E | uint8 | read, write, notify | 0-1 | ✗ |

---

## Humidifier Dehumidifier (0xBD)

**UUID:** `000000BD-0000-1000-8000-0026BB765291`

This service can describe a humidifier, a dehumidifier, or a combo device that does both.

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Active | 0xB0 | uint8 | read, write, notify | 0-1 | 0=INACTIVE, 1=ACTIVE | ✓ read/write |
| Current Relative Humidity | 0x10 | float | read, notify | 0-100 | percentage | ✓ read |
| Current Humidifier Dehumidifier State | 0xB3 | uint8 | read, notify | 0-3 | 0=INACTIVE, 1=IDLE, 2=HUMIDIFYING, 3=DEHUMIDIFYING | ✓ read |
| Target Humidifier Dehumidifier State | 0xB4 | uint8 | read, write, notify | 0-2 | 0=AUTO, 1=HUMIDIFIER, 2=DEHUMIDIFIER | ✓ read/write (1 and 2 only) |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Relative Humidity Dehumidifier Threshold | 0xC9 | float | read, write, notify | 0-100 | ✓ read/write |
| Relative Humidity Humidifier Threshold | 0xCA | float | read, write, notify | 0-100 | ✓ read/write |
| Rotation Speed | 0x29 | float | read, write, notify | 0-100 | ✗ |
| Swing Mode | 0xB6 | uint8 | read, write, notify | 0-1 | ✓ read/write |
| Water Level | 0xB5 | float | read, notify | 0-100 | ✗ |
| Lock Physical Controls | 0xA7 | uint8 | read, write, notify | 0-1 | ✗ |

**Device type detection:**

The presence of threshold characteristics determines the device type:
- **Humidifier only:** Has Humidifier Threshold, no Dehumidifier Threshold
- **Dehumidifier only:** Has Dehumidifier Threshold, no Humidifier Threshold
- **Combo device:** Has both thresholds

**Mode support:**

- Value 0 (AUTO) is not supported. Per the HAP spec, AUTO mode is only valid for combo devices and requires both thresholds.
- Itsyhome shows both Humid and Dry mode buttons, with unsupported modes disabled based on device type.

---

## Air Purifier (0xBB)

**UUID:** `000000BB-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Active | 0xB0 | uint8 | read, write, notify | 0-1 | 0=INACTIVE, 1=ACTIVE | ✓ read/write |
| Current Air Purifier State | 0xA9 | uint8 | read, notify | 0-2 | 0=INACTIVE, 1=IDLE, 2=PURIFYING_AIR | ✓ read |
| Target Air Purifier State | 0xA8 | uint8 | read, write, notify | 0-1 | 0=MANUAL, 1=AUTO | ✓ read/write |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Rotation Speed | 0x29 | float | read, write, notify | 0-100 | ✓ read/write |
| Swing Mode | 0xB6 | uint8 | read, write, notify | 0-1 | ✓ read/write |
| Lock Physical Controls | 0xA7 | uint8 | read, write, notify | 0-1 | ✗ |

---

## Valve (0xD0)

**UUID:** `000000D0-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Active | 0xB0 | uint8 | read, write, notify | 0-1 | 0=INACTIVE, 1=ACTIVE | ✓ read/write |
| In Use | 0xD2 | uint8 | read, notify | 0-1 | 0=NOT_IN_USE, 1=IN_USE | ✓ read |
| Valve Type | 0xD5 | uint8 | read, notify | 0-3 | 0=GENERIC, 1=IRRIGATION, 2=SHOWER_HEAD, 3=WATER_FAUCET | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Set Duration | 0xD3 | uint32 | read, write, notify | 0-3600 | ✗ |
| Remaining Duration | 0xD4 | uint32 | read, notify | 0-3600 | ✗ |
| Is Configured | 0xD6 | uint8 | read, write, notify | 0-1 | ✗ |
| Service Label Index | 0xCB | uint8 | read | 1+ | ✗ |
| Status Fault | 0x77 | uint8 | read, notify | 0-1 | ✗ |

**Gap:** Set Duration and Remaining Duration are available but not implemented in Itsyhome. This would allow timed watering.

---

## Faucet (0xD7)

**UUID:** `000000D7-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Active | 0xB0 | uint8 | read, write, notify | 0-1 | 0=INACTIVE, 1=ACTIVE | ✓ read/write |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Status Fault | 0x77 | uint8 | read, notify | 0-1 | ✗ |

---

## Slat (0xB9)

**UUID:** `000000B9-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Current Slat State | 0xAA | uint8 | read, notify | 0-2 | 0=FIXED, 1=JAMMED, 2=SWINGING | ✓ read |
| Slat Type | 0xC0 | uint8 | read | 0-1 | 0=HORIZONTAL, 1=VERTICAL | ✓ read |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Current Tilt Angle | 0xC1 | int | read, notify | -90 to 90 | ✓ read |
| Target Tilt Angle | 0xC2 | int | read, write, notify | -90 to 90 | ✓ read/write |
| Swing Mode | 0xB6 | uint8 | read, write, notify | 0-1 | ✓ read/write |

---

## Security System (0x7E)

**UUID:** `0000007E-0000-1000-8000-0026BB765291`

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values | Itsyhome |
|----------------|------|--------|-------------|-------|--------|----------|
| Security System Current State | 0x66 | uint8 | read, notify | 0-4 | 0=STAY_ARM, 1=AWAY_ARM, 2=NIGHT_ARM, 3=DISARMED, 4=ALARM_TRIGGERED | ✓ read |
| Security System Target State | 0x67 | uint8 | read, write, notify | 0-3 | 0=STAY_ARM, 1=AWAY_ARM, 2=NIGHT_ARM, 3=DISARM | ✓ read/write |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Itsyhome |
|----------------|------|--------|-------------|-------|----------|
| Security System Alarm Type | 0x8E | uint8 | read, notify | 0-1 | ✗ |
| Status Fault | 0x77 | uint8 | read, notify | 0-1 | ✗ |
| Status Tampered | 0x7A | uint8 | read, notify | 0-1 | ✗ |

---

## Itsyhome gaps summary

| Accessory | Missing characteristic | HAP permissions | Impact |
|-----------|----------------------|-----------------|--------|
| Valve | Set Duration | read, write, notify | Cannot set auto-shutoff timer |
| Valve | Remaining Duration | read, notify | Cannot see time remaining |

---

## Future implementation

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

**Required characteristics:**

| Characteristic | UUID | Format | Permissions | Range | Values |
|----------------|------|--------|-------------|-------|--------|
| Active | 0xB0 | uint8 | read, write, notify | 0-1 | 0=INACTIVE, 1=ACTIVE |
| Program Mode | 0xD1 | uint8 | read, notify | 0-2 | 0=NO_PROGRAM, 1=SCHEDULED, 2=SCHEDULED_MANUAL |
| In Use | 0xD2 | uint8 | read, notify | 0-1 | 0=NOT_IN_USE, 1=IN_USE |

**Optional characteristics:**

| Characteristic | UUID | Format | Permissions | Range |
|----------------|------|--------|-------------|-------|
| Remaining Duration | 0xD4 | uint32 | read, notify | 0-3600 |
| Status Fault | 0x77 | uint8 | read, notify | 0-1 |

**Linked services:** One or more Valve services (required), ServiceLabel for zone naming.
