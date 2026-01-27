# All HomeKit accessories

| Hex | Service | Supported |
|-----|---------|-----------|
| 0x40 | Fan (v1) | ✓ |
| 0xB7 | Fan (v2) | ✓ |
| 0x41 | Garage Door Opener | ✓ |
| 0x43 | Lightbulb | ✓ |
| 0x45 | Lock Mechanism | ✓ |
| 0x47 | Outlet | ✓ |
| 0x49 | Switch | ✓ |
| 0x4A | Thermostat | ✓ |
| 0x7E | Security System | ✓ |
| 0x80 | Contact Sensor | ✓ |
| 0x82 | Humidity Sensor | ✓ |
| 0x85 | Motion Sensor | ✓ |
| 0x8A | Temperature Sensor | ✓ |
| 0x8C | Window Covering | ✓ |
| 0xBB | Air Purifier | ✓ |
| 0xBC | Heater Cooler | ✓ |
| 0xBD | Humidifier Dehumidifier | ✓ |
| 0xD0 | Valve | ✓ |
| 0x81 | Door | ✓ |
| 0x8B | Window | ✓ |
| 0xB9 | Slat | ✓ |
| 0xD7 | Faucet | ✓ |
| 0x7F | Carbon Monoxide Sensor | ❌ |
| 0x83 | Leak Sensor | ❌ |
| 0x84 | Light Sensor | ❌ |
| 0x86 | Occupancy Sensor | ❌ |
| 0x87 | Smoke Sensor | ❌ |
| 0x89 | Stateless Programmable Switch | ❌ |
| 0x8D | Air Quality Sensor | ❌ |
| 0x97 | Carbon Dioxide Sensor | ❌ |
| 0xCF | Irrigation System | ❌ |
| 0x121 | Doorbell | ❌ |

---

## Irrigation System (0xCF)

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

**Sources:**
- [Apple HomeKitADK - HAPServiceTypes.h](https://github.com/apple/HomeKitADK/blob/master/HAP/HAPServiceTypes.h)
- [NRCHKB Irrigation System](https://nrchkb.github.io/wiki/service/irrigation-system/)
- [esp-homekit-devices Wiki - Service Types](https://github.com/ravensystem/esp-homekit-devices/wiki/Service-Types)
- [Apple HMCharacteristicTypeTargetTilt](https://developer.apple.com/documentation/homekit/hmcharacteristictypetargettilt)
- [Homebridge HAP-NodeJS](https://developers.homebridge.io/HAP-NodeJS/classes/Service.html)
