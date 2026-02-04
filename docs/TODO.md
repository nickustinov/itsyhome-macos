# HomeKit service groups integration

## What we found

- HomeKit exposes native accessory groups via `HMServiceGroup` on `HMHome.serviceGroups`
- The `/debug/raw` endpoint now returns these, and we confirmed 12 service groups exist in the current home
- Some groups have services populated (e.g. "Office Floor Lamps" with 2 outlets, "Living Room Floor Lamps" with 3 lights, "Kitchen Blinds"), while others have empty services arrays ("Living Room Curtains", "Vinyl Shelf", "Floorlights") which may be stale or created differently
- `HMServiceGroup` API: `name`, `uniqueIdentifier`, `services` array, plus methods to `addService`/`removeService`

## Model mismatch with ItsyHome groups

ItsyHome's `DeviceGroup` has two properties that `HMServiceGroup` does not:

1. **`roomId`** - optional room assignment. HMServiceGroup has no room concept, it's a flat list at the home level
2. **`icon`** - custom icon per group. HMServiceGroup has no icon property

ItsyHome groups are stored locally via `PreferencesManager` and reference service UUIDs in `deviceIds`.

## Room assignment

HMServiceGroup doesn't support rooms natively, but room can be inferred: if all services in a group belong to the same room, treat it as belonging to that room. If services span multiple rooms, treat it as a global (no-room) group. This matches how ItsyHome groups already work.

## Options for integration

### Option A: read-only import from HomeKit
- Import HMServiceGroups as ItsyHome DeviceGroups on load
- Infer `roomId` from services
- Infer `icon` from service types (already have `DeviceGroup.inferIcon`)
- Local groups stay local, HomeKit groups are read-only in ItsyHome
- Simplest approach, no write-back complexity

### Option B: two-way sync
- Map ItsyHome groups to HMServiceGroups and vice versa
- Store `roomId` and `icon` as local metadata keyed by HMServiceGroup UUID
- Creating/editing a group in ItsyHome writes to HomeKit
- Changes in HomeKit reflected in ItsyHome
- More complex, need to handle conflicts and merge logic

### Option C: migration with two-way going forward
- On first run, offer to push existing local groups to HomeKit as HMServiceGroups
- Going forward, all group CRUD goes through HomeKit API
- `roomId` and `icon` stored as local metadata keyed by HMServiceGroup UUID
- Existing local groups that weren't migrated get deleted or kept as legacy

## Open questions

- What are the empty-services groups? Are they stale, or created by a different mechanism? Worth investigating
- Do we want groups to sync across Apple devices via HomeKit, or is local-only fine?
- If syncing, how do we handle the case where someone edits groups on their iPhone and ItsyHome needs to pick up changes?
- Should there be a UI to distinguish HomeKit groups from local groups, or should they be unified?
- Performance: does reading/writing HMServiceGroups have any latency or permission issues?
