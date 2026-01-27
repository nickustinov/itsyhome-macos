# HomeKit Accessory Protocol specification

This folder contains the HAP specification and a tool to query it.

## Files

- `homekit-spec.md` - HomeKit Accessory Protocol specification (markdown format)
- `hap-spec.py` - Script to query service and characteristic definitions
- `accessories.md` - Supported accessories and their characteristics

## HAP spec lookup

The `hap-spec.py` script queries service and characteristic definitions from the HAP specification. It extracts UUIDs, properties, valid values, and follows references to linked sections.

### Usage

```bash
# Look up a service definition (chapter 8)
./hap-spec.py --service Lightbulb      # Handles "Light Bulb" variation
./hap-spec.py --service Thermostat
./hap-spec.py --service Faucet

# Look up a characteristic definition (chapter 9)
./hap-spec.py --char Brightness
./hap-spec.py --char On
./hap-spec.py --char "Target Temperature"

# List all services or characteristics
./hap-spec.py --list-services
./hap-spec.py --list-characteristics

# General search
./hap-spec.py "Active"
```

### Output

For services, output includes:
- Service UUID and type
- Required characteristics
- Optional characteristics
- Full content of all referenced sections

For characteristics, output includes:
- Characteristic UUID and type
- Permissions (read, write, notify)
- Format (int, float, string, etc.)
- Min/max/step values
- Valid values with descriptions

### Example

```bash
$ ./hap-spec.py --service Thermostat
```

```
### Service: Thermostat
============================================================
##### 8.42 Thermostat

This service describes a thermostat.

|Property|Value|
|---|---|
|**UUID**|0000004A-0000-1000-8000-0026BB765291|
|**Type**|public.hap.service.thermostat|
|**Required Characteristics**|"9.32 Current Heating Cooling State"...|
|**Optional Characteristics**|"9.20 Cooling Threshold Temperature"...|

============================================================
### Referenced sections
============================================================

--- 9.32 Current Heating Cooling State ---
##### 9.32 Current Heating Cooling State

This characteristic describes the current mode of an accessory...

|Property|Value|
|---|---|
|**UUID**|0000000F-0000-1000-8000-0026BB765291|
|**Permissions**|Paired Read, Notify|
|**Format**|uint8|
|**Valid Values**|0 "Off", 1 "Heat", 2 "Cool"|
...
```
