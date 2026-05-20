//
//  WebhookServer+Endpoints.swift
//  macOSBridge
//
//  Read endpoint handlers for webhook server
//

import Foundation
import Network
import AppKit

extension WebhookServer {

    // MARK: - User-defined ordering helpers
    //
    // These mirror the same predicates the menubar dropdown applies so the
    // webhook returns rooms / scenes / accessories / groups in the order the
    // user chose in Settings → Accessories.

    fileprivate func sortByOrder<T>(_ items: [T], idOf: (T) -> String, savedOrder: [String]) -> [T] {
        return items.sorted { a, b in
            let i1 = savedOrder.firstIndex(of: idOf(a)) ?? Int.max
            let i2 = savedOrder.firstIndex(of: idOf(b)) ?? Int.max
            return i1 < i2
        }
    }

    fileprivate func orderedRooms(_ rooms: [RoomData]) -> [RoomData] {
        let preferences = PreferencesManager.shared
        let visible = rooms.filter { !preferences.isHidden(roomId: $0.uniqueIdentifier) }
        return sortByOrder(visible, idOf: { $0.uniqueIdentifier }, savedOrder: preferences.roomOrder)
    }

    fileprivate func orderedScenes(_ scenes: [SceneData]) -> [SceneData] {
        let preferences = PreferencesManager.shared
        let visible = scenes.filter { !preferences.isHidden(sceneId: $0.uniqueIdentifier) }
        return sortByOrder(visible, idOf: { $0.uniqueIdentifier }, savedOrder: preferences.sceneOrder)
    }

    fileprivate func orderedGroups(_ groups: [DeviceGroup], roomId: String?) -> [DeviceGroup] {
        let preferences = PreferencesManager.shared
        let order = roomId.map { preferences.groupOrder(forRoom: $0) } ?? preferences.globalGroupOrder
        return sortByOrder(groups, idOf: { $0.id }, savedOrder: order)
    }

    // Apply the per-room accessory order to a flat list of services. Entries
    // that aren't in the saved order land at the end in their original
    // sequence. Divider tokens (used by the menubar to insert separators) are
    // skipped — the webhook list doesn't have a separator concept.
    fileprivate func orderedServices(_ services: [ServiceData], roomId: String?) -> [ServiceData] {
        let preferences = PreferencesManager.shared
        let visible = services.filter { !preferences.isHidden(serviceId: $0.uniqueIdentifier) }
        guard let roomId = roomId else { return visible }
        let savedOrder = preferences.accessoryOrder(forRoom: roomId)
        guard !savedOrder.isEmpty else { return visible }

        let lookup = Dictionary(visible.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        var seen: Set<String> = []
        var result: [ServiceData] = []
        for token in savedOrder {
            if token.hasPrefix(PreferencesManager.dividerPrefix) { continue }
            if let svc = lookup[token] {
                result.append(svc)
                seen.insert(token)
            }
        }
        for svc in visible where !seen.contains(svc.uniqueIdentifier) {
            result.append(svc)
        }
        return result
    }

    // MARK: - Read endpoints

    func handleReadRequest(path: String, connection: NWConnection, engine: ActionEngine) -> Bool {
        let components = path.split(separator: "/", maxSplits: 3).map { String($0) }

        switch components.first {
        case "status":
            handleStatus(connection: connection, engine: engine)
            return true
        case "refresh":
            engine.bridge?.reloadHomeKit()
            sendResponse(connection: connection, status: 200, body: encode(APIResponse.success))
            return true
        case "list":
            guard components.count >= 2 else {
                sendResponse(connection: connection, status: 400, body: encode(APIResponse.error("Usage: /list/rooms|devices|scenes|groups")))
                return true
            }
            handleList(type: components[1], room: components.count > 2 ? components[2] : nil, connection: connection, engine: engine)
            return true
        case "info":
            let rest = path.dropFirst(5) // drop "info/"
            let decoded = String(rest).removingPercentEncoding ?? String(rest)
            handleInfo(target: decoded, connection: connection, engine: engine)
            return true
        case "icon":
            // /icon/<phosphor-name>[?fill=1][&size=64]
            let rest = String(path.dropFirst(5)) // drop "icon/"
            let qIdx = rest.firstIndex(of: "?")
            let namePart = qIdx.map { String(rest[..<$0]) } ?? rest
            let queryStr = qIdx.map { String(rest[rest.index(after: $0)...]) } ?? ""
            let name = namePart.removingPercentEncoding ?? namePart
            handleIcon(name: name, queryString: queryStr, connection: connection)
            return true
        case "debug":
            let rest = path.dropFirst(6) // drop "debug/"
            let decoded = String(rest).removingPercentEncoding ?? String(rest)
            if decoded == "raw" {
                handleDebugRaw(connection: connection, engine: engine)
            } else if decoded == "all" {
                handleDebugAll(connection: connection, engine: engine)
            } else if decoded == "cameras" || decoded.hasPrefix("cameras/") {
                let entityFilter = decoded.hasPrefix("cameras/") ? String(decoded.dropFirst(8)) : nil
                handleDebugCameras(connection: connection, engine: engine, entityId: entityFilter)
            } else {
                handleDebug(target: decoded, connection: connection, engine: engine)
            }
            return true
        default:
            return false
        }
    }

    // MARK: - Icon

    /// Render a Phosphor icon by name to PNG. Query params:
    ///   fill=1   → use the filled variant (default: regular outline)
    ///   size=N   → output pixel size, clamped to 16…256 (default: 96)
    /// Icons are rendered white-on-transparent so clients can paint them on
    /// dark backgrounds (e.g. the Even G2's black canvas).
    fileprivate func handleIcon(name: String, queryString: String, connection: NWConnection) {
        var fill = false
        var size = 96
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = String(kv[0])
            let value = String(kv[1])
            switch key {
            case "fill": fill = (value == "1" || value.lowercased() == "true")
            case "size": if let n = Int(value) { size = n }
            default: break
            }
        }
        size = max(16, min(size, 256))

        guard let image = PhosphorIcon.icon(name, filled: fill) else {
            sendResponse(connection: connection, status: 404, body: encode(APIResponse.error("Icon not found: \(name)")))
            return
        }

        guard let png = renderIconPNG(image, size: CGFloat(size)) else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("Icon render failed")))
            return
        }

        sendBinaryResponse(connection: connection, contentType: "image/png", body: png)
    }

    private func renderIconPNG(_ image: NSImage, size: CGFloat) -> Data? {
        let pixelSize = NSSize(width: size, height: size)
        // Oversample 2x then encode at the requested size so the SVG
        // rasterises at sub-pixel precision before final downsampling. At
        // 28px this is the difference between blocky edges and clean
        // glyphs, since the firmware quantises to gray4 afterwards.
        let scale: CGFloat = 2.0
        let supersampled = NSSize(width: size * scale, height: size * scale)
        guard let bigRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(supersampled.width),
            pixelsHigh: Int(supersampled.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        bigRep.size = supersampled

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: bigRep)
        ctx?.imageInterpolation = .high
        NSGraphicsContext.current = ctx
        let bigRect = NSRect(origin: .zero, size: supersampled)
        // Transparent background: the template SVG paints onto a clear
        // canvas, the icon's stroke alpha becomes the rendered alpha.
        // sourceAtop then tints only the painted pixels to white — using an
        // opaque black background here would set alpha=1 across the whole
        // square and the white fill would clobber everything (turning
        // template outline icons into flat white squares).
        image.draw(in: bigRect, from: .zero, operation: .sourceOver, fraction: 1.0,
                   respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.high])
        NSColor.white.set()
        bigRect.fill(using: .sourceAtop)
        NSGraphicsContext.restoreGraphicsState()

        // Downsample the supersampled bitmap to the requested pixel size.
        // RGBA so the icon's alpha mask survives the resize.
        guard let finalRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        finalRep.size = pixelSize

        NSGraphicsContext.saveGraphicsState()
        let outCtx = NSGraphicsContext(bitmapImageRep: finalRep)
        outCtx?.imageInterpolation = .high
        NSGraphicsContext.current = outCtx
        let outRect = NSRect(origin: .zero, size: pixelSize)
        bigRep.draw(in: outRect, from: NSRect(origin: .zero, size: supersampled),
                    operation: .sourceOver, fraction: 1.0,
                    respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()

        return finalRep.representation(using: .png, properties: [:])
    }

    // MARK: - Status

    private func handleStatus(connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        let allServices = data.accessories.flatMap { $0.services }
        let reachableCount = data.accessories.filter { $0.isReachable }.count

        let response = StatusResponse(
            rooms: data.rooms.count,
            devices: allServices.count,
            accessories: data.accessories.count,
            reachable: reachableCount,
            unreachable: data.accessories.count - reachableCount,
            scenes: data.scenes.count,
            groups: PreferencesManager.shared.deviceGroups.count
        )
        sendResponse(connection: connection, status: 200, body: encode(response))
    }

    // MARK: - List

    private func handleList(type: String, room: String?, connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        switch type {
        case "rooms":
            let items = orderedRooms(data.rooms).map { room in
                RoomListItem(
                    name: room.name,
                    icon: IconResolver.iconName(forRoomId: room.uniqueIdentifier, roomName: room.name)
                )
            }
            sendResponse(connection: connection, status: 200, body: encode(items))

        case "devices":
            let roomLookup = data.roomLookup()
            var items: [DeviceListItem] = []

            // Walk rooms in the user-defined order so /list/devices?room=X and
            // the full list both honour the menubar's room ordering.
            let filterRoomLower = room?.removingPercentEncoding?.lowercased()

            // Group services by room first.
            var servicesByRoom: [String?: [ServiceData]] = [:]
            for accessory in data.accessories {
                for service in accessory.services {
                    servicesByRoom[accessory.roomIdentifier, default: []].append(service)
                }
            }

            for room in orderedRooms(data.rooms) {
                let roomName = room.name
                if let filter = filterRoomLower, roomName.lowercased() != filter { continue }
                let services = orderedServices(servicesByRoom[room.uniqueIdentifier] ?? [], roomId: room.uniqueIdentifier)
                for service in services {
                    let accessory = data.accessories.first { $0.services.contains(where: { $0.uniqueIdentifier == service.uniqueIdentifier }) }
                    items.append(DeviceListItem(
                        name: service.name,
                        type: serviceTypeLabel(service.serviceType),
                        icon: IconResolver.iconName(for: service),
                        reachable: accessory?.isReachable ?? false,
                        room: roomName
                    ))
                }
            }

            // Roomless accessories (the menubar's "Other" section) come last.
            if filterRoomLower == nil {
                let roomless = orderedServices(servicesByRoom[nil] ?? [], roomId: nil)
                for service in roomless {
                    let accessory = data.accessories.first { $0.services.contains(where: { $0.uniqueIdentifier == service.uniqueIdentifier }) }
                    items.append(DeviceListItem(
                        name: service.name,
                        type: serviceTypeLabel(service.serviceType),
                        icon: IconResolver.iconName(for: service),
                        reachable: accessory?.isReachable ?? false,
                        room: nil
                    ))
                }
            }

            sendResponse(connection: connection, status: 200, body: encode(items))

        case "scenes":
            let items = orderedScenes(data.scenes).map { scene in
                SceneListItem(name: scene.name, icon: IconResolver.iconName(for: scene))
            }
            sendResponse(connection: connection, status: 200, body: encode(items))

        case "groups":
            let allGroups = PreferencesManager.shared.deviceGroups
            let roomLookup = data.roomLookup()
            let roomIdLookup = Dictionary(data.rooms.map { ($0.name.lowercased(), $0.uniqueIdentifier) }, uniquingKeysWith: { first, _ in first })

            // Filter by room if specified — room-scoped groups for that room
            // plus any global (roomId == nil) groups also surface there.
            var ordered: [DeviceGroup] = []
            if let filterRoom = room?.removingPercentEncoding,
               let filterRoomId = roomIdLookup[filterRoom.lowercased()] {
                let scoped = allGroups.filter { $0.roomId == filterRoomId }
                let global = allGroups.filter { $0.roomId == nil }
                ordered = orderedGroups(scoped, roomId: filterRoomId) + orderedGroups(global, roomId: nil)
            } else {
                // No filter: emit by room in user-defined room order, then global last.
                var groupsByRoom: [String: [DeviceGroup]] = [:]
                var globalGroups: [DeviceGroup] = []
                for group in allGroups {
                    if let roomId = group.roomId {
                        groupsByRoom[roomId, default: []].append(group)
                    } else {
                        globalGroups.append(group)
                    }
                }
                for room in orderedRooms(data.rooms) {
                    let inRoom = groupsByRoom[room.uniqueIdentifier] ?? []
                    ordered.append(contentsOf: orderedGroups(inRoom, roomId: room.uniqueIdentifier))
                }
                ordered.append(contentsOf: orderedGroups(globalGroups, roomId: nil))
            }

            let items = ordered.map { group in
                GroupListItem(
                    name: group.name,
                    icon: group.icon,
                    devices: group.deviceIds.count,
                    room: group.roomId.flatMap { roomLookup[$0] }
                )
            }
            sendResponse(connection: connection, status: 200, body: encode(items))

        case "favourites", "favorites":
            sendResponse(connection: connection, status: 200, body: encode(buildFavourites(data: data)))

        default:
            sendResponse(connection: connection, status: 400, body: encode(APIResponse.error("Unknown list type: \(type). Use rooms, devices, scenes, groups, or favourites.")))
        }
    }

    /// Build the favourites list from PreferencesManager's user-curated
    /// favourites (NOT menubar pins – those are a separate concept).
    /// IDs come from `orderedFavouriteIds`:
    ///   "groupFav:<groupId>" → device-group favourite
    ///   else, a raw scene or service ID (disambiguated via the typed sets
    ///   `orderedFavouriteSceneIds` / `orderedFavouriteServiceIds`).
    /// Items resolving to a deleted/hidden entity are skipped. Order matches
    /// the user's drag-ordered favourites list (no alphabetical sort).
    private func buildFavourites(data: MenuData) -> [FavouriteListItem] {
        let preferences = PreferencesManager.shared
        let ordered = preferences.orderedFavouriteIds
        let sceneIds = Set(preferences.orderedFavouriteSceneIds)
        let serviceIds = Set(preferences.orderedFavouriteServiceIds)
        let roomLookup = Dictionary(data.rooms.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
        let sceneLookup = Dictionary(data.scenes.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
        let allServices = data.accessories.flatMap { $0.services }
        let serviceLookup = Dictionary(allServices.map { ($0.uniqueIdentifier, $0) }, uniquingKeysWith: { a, _ in a })
        let deviceGroups = preferences.deviceGroups

        var items: [FavouriteListItem] = []
        for favId in ordered {
            if favId.hasPrefix("groupFav:") {
                let groupId = String(favId.dropFirst("groupFav:".count))
                guard let group = deviceGroups.first(where: { $0.id == groupId }) else { continue }
                items.append(FavouriteListItem(
                    kind: "group",
                    name: group.name,
                    icon: group.icon,
                    type: nil,
                    room: group.roomId.flatMap { roomLookup[$0]?.name },
                    reachable: true
                ))
                continue
            }
            if sceneIds.contains(favId) {
                guard let scene = sceneLookup[favId], !preferences.isHidden(sceneId: favId) else { continue }
                items.append(FavouriteListItem(
                    kind: "scene",
                    name: scene.name,
                    icon: IconResolver.iconName(for: scene)
                ))
                continue
            }
            if serviceIds.contains(favId) {
                guard let service = serviceLookup[favId], !preferences.isHidden(serviceId: favId) else { continue }
                let accessory = data.accessories.first { $0.services.contains(where: { $0.uniqueIdentifier == favId }) }
                let roomName = accessory?.roomIdentifier.flatMap { roomLookup[$0]?.name }
                items.append(FavouriteListItem(
                    kind: "service",
                    name: service.name,
                    icon: IconResolver.iconName(for: service),
                    type: serviceTypeLabel(service.serviceType),
                    room: roomName,
                    reachable: accessory?.isReachable ?? false
                ))
                continue
            }
        }

        return items
    }

    // MARK: - Info

    private func handleInfo(target: String, connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        let lowered = target.lowercased()

        // Try exact room name match first (avoids space-splitting issues)
        if let room = data.rooms.first(where: { $0.name.lowercased() == lowered }) {
            let roomServices = data.accessories.filter { $0.roomIdentifier == room.uniqueIdentifier }
                .flatMap { $0.services }
            // Apply the user's per-room accessory ordering so /info/Room
            // mirrors the order shown in the menubar's room submenu.
            let ordered = orderedServices(roomServices, roomId: room.uniqueIdentifier)
            let items = ordered.map { buildServiceInfo($0, in: data, engine: engine) }
            sendResponse(connection: connection, status: 200, body: encode(items))
            return
        }

        // Try exact device name match
        let exactDevices = data.accessories.flatMap { $0.services }
            .filter { $0.name.lowercased() == lowered }
        if !exactDevices.isEmpty {
            sendServiceInfoResponse(exactDevices, data: data, engine: engine, connection: connection)
            return
        }

        // Use DeviceResolver for Room/Device, group, scene, UUID formats
        let resolved = DeviceResolver.resolve(target, in: data, groups: PreferencesManager.shared.deviceGroups)

        switch resolved {
        case .services(let services):
            sendServiceInfoResponse(services, data: data, engine: engine, connection: connection)

        case .scene(let scene):
            let response = SceneInfoResponse(
                name: scene.name,
                type: "scene",
                icon: IconResolver.iconName(for: scene)
            )
            sendResponse(connection: connection, status: 200, body: encode(response))

        case .ambiguous(let services):
            // /info is a read-only query — returning all matches is safe and
            // more useful than 404 when a room contains multiple devices that
            // share the same name (e.g. thermostat + switch both named "Bathroom").
            sendServiceInfoResponse(services, data: data, engine: engine, connection: connection)

        case .notFound:
            sendResponse(connection: connection, status: 404, body: encode(APIResponse.error("Not found: \(target)")))
        }
    }

    // MARK: - Debug

    private func handleDebug(target: String, connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        let lowered = target.lowercased()

        // Find matching services
        let matchingServices = data.accessories.flatMap { $0.services }
            .filter { $0.name.lowercased() == lowered || $0.accessoryName.lowercased() == lowered }

        if matchingServices.isEmpty {
            sendResponse(connection: connection, status: 404, body: encode(APIResponse.error("Not found: \(target)")))
            return
        }

        let items = matchingServices.map { buildDebugService($0, in: data, engine: engine) }
        if items.count == 1 {
            sendResponse(connection: connection, status: 200, body: encode(items[0]))
        } else {
            sendResponse(connection: connection, status: 200, body: encode(items))
        }
    }

    private func handleDebugAll(connection: NWConnection, engine: ActionEngine) {
        guard let data = engine.menuData else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("No data available")))
            return
        }

        let roomLookup = data.roomLookup()

        let accessoryInfos = data.accessories.map { accessory in
            DebugAccessoryInfo(
                name: accessory.name,
                reachable: accessory.isReachable,
                services: accessory.services.map { buildDebugService($0, in: data, engine: engine) },
                room: accessory.roomIdentifier.flatMap { roomLookup[$0] }
            )
        }

        let response = DebugAllResponse(
            accessories: accessoryInfos,
            rooms: data.rooms.count,
            scenes: data.scenes.count
        )
        sendResponse(connection: connection, status: 200, body: encode(response))
    }

    private func handleDebugCameras(connection: NWConnection, engine: ActionEngine, entityId: String? = nil) {
        guard let bridge = engine.bridge else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("Bridge unavailable")))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                connection.cancel()
                return
            }
            bridge.getCameraDebugJSON(entityId: entityId) { json in
                if let json = json {
                    self.sendResponse(connection: connection, status: 200, body: json)
                } else {
                    self.sendResponse(connection: connection, status: 500, body: self.encode(APIResponse.error("Camera debug not available (HomeKit mode?)")))
                }
            }
        }
    }

    private func handleDebugRaw(connection: NWConnection, engine: ActionEngine) {
        guard let bridge = engine.bridge else {
            sendResponse(connection: connection, status: 500, body: encode(APIResponse.error("Bridge unavailable")))
            return
        }

        // Request raw HomeKit dump from iOS - must run on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                connection.cancel()
                return
            }
            if let rawData = bridge.getRawHomeKitDump() {
                self.sendResponse(connection: connection, status: 200, body: rawData)
            } else {
                self.sendResponse(connection: connection, status: 500, body: self.encode(APIResponse.error("Failed to get raw HomeKit data")))
            }
        }
    }

    // MARK: - Response builders

    private func sendServiceInfoResponse(_ services: [ServiceData], data: MenuData, engine: ActionEngine, connection: NWConnection) {
        let items = services.map { buildServiceInfo($0, in: data, engine: engine) }
        if items.count == 1 {
            sendResponse(connection: connection, status: 200, body: encode(items[0]))
        } else {
            sendResponse(connection: connection, status: 200, body: encode(items))
        }
    }

    /// Unified list of climate modes the device will actually accept,
    /// normalised to the HA string vocabulary so clients can render one
    /// vocabulary regardless of whether the underlying device is HA-bridged
    /// or HK-native. Returns nil for non-climate services.
    ///
    /// Quirks mirrored from the menubar menu items:
    ///   - HA climate (HAClimateMenuItem): use `availableHVACModes` as-is.
    ///   - HK Thermostat (ThermostatMenuItem): `validTargetHeatingCoolingStates`
    ///     is a subset of [0,1,2,3] → off/heat/cool/auto. Defaults to all four.
    ///   - HK HeaterCooler (ACMenuItem): `validTargetHeaterCoolerStates` is
    ///     a subset of [0,1,2] → auto/heat/cool. "off" is exposed via the
    ///     separate Active characteristic, so prepend it when an `activeId`
    ///     exists. Defaults to [auto,heat,cool] plus off.
    private func climateAvailableModes(for service: ServiceData) -> [String]? {
        if let modes = service.availableHVACModes, !modes.isEmpty {
            return modes
        }
        if service.targetHeatingCoolingStateId != nil {
            let labels: [Int: String] = [0: "off", 1: "heat", 2: "cool", 3: "auto"]
            let valid = service.validTargetHeatingCoolingStates ?? [0, 1, 2, 3]
            return valid.compactMap { labels[$0] }
        }
        if service.targetHeaterCoolerStateId != nil {
            let labels: [Int: String] = [0: "auto", 1: "heat", 2: "cool"]
            let valid = service.validTargetHeaterCoolerStates ?? [0, 1, 2]
            var modes = valid.compactMap { labels[$0] }
            if service.activeId != nil { modes.insert("off", at: 0) }
            return modes
        }
        return nil
    }

    private func buildServiceInfo(_ service: ServiceData, in data: MenuData, engine: ActionEngine) -> ServiceInfoResponse {
        let roomLookup = data.roomLookup()
        let accessory = data.accessories.first { $0.services.contains(where: { $0.uniqueIdentifier == service.uniqueIdentifier }) }
        let roomName = accessory?.roomIdentifier.flatMap { roomLookup[$0] }

        // Helper to get characteristic value
        func getValue(_ idString: String?) -> Any? {
            guard let idStr = idString, let uuid = UUID(uuidString: idStr) else { return nil }
            return engine.bridge?.getCharacteristicValue(identifier: uuid)
        }

        // Build state
        var state = ServiceState()

        // Power state: prefer the `Active` characteristic when present. Fans
        // (FanV2), AC (HeaterCooler) and Valves use `Active` as their
        // canonical power switch — `On` (powerStateId) may still be exposed
        // by the accessory but its cached value can drift behind `Active`,
        // which is exactly what the menubar item resolves against
        // (FanMenuItem: `activeId ?? powerStateId`).
        if let value = getValue(service.activeId) {
            state.on = intValue(value) != 0
        } else if let value = getValue(service.powerStateId) {
            state.on = boolValue(value)
        } else if let value = getValue(service.targetHeatingCoolingStateId) {
            state.on = intValue(value) != 0
        }

        if let value = getValue(service.brightnessId) {
            state.brightness = intValue(value)
        }
        if let value = getValue(service.currentPositionId) {
            state.position = intValue(value)
        }
        if let value = getValue(service.currentTemperatureId) {
            state.temperature = doubleValue(value)
        }
        if let value = getValue(service.targetTemperatureId) {
            state.targetTemperature = doubleValue(value)
        }
        // Auto-mode thermostats (e.g. Ecobee) and HeaterCooler ACs expose
        // these instead of (or alongside) a single targetTemperature.
        // Surface both raw values so clients can render a true lo/hi band
        // rather than the misleading single-number fallback we used to
        // synthesise here.
        if let value = getValue(service.heatingThresholdTemperatureId) {
            state.heatingThreshold = doubleValue(value)
        }
        if let value = getValue(service.coolingThresholdTemperatureId) {
            state.coolingThreshold = doubleValue(value)
        }

        // Mode. For HA climate the bridge stores HA-specific modes as extended
        // ints beyond the HK 0-3 range (see EntityMapper.mapHVACModeToHomeKit:
        // 3=heat_cool, 4=dry, 5=fan_only, 6=auto). Falling through to
        // TargetThermostatState dropped 4/5/6 to "off" and labelled 3 as
        // HK's "auto", so the UI lied about the current mode. Detect HA by
        // the presence of availableHVACModes and translate explicitly.
        if let value = getValue(service.heatingCoolingStateId) {
            state.mode = ThermostatState(rawValue: intValue(value))?.label ?? "off"
        } else if let value = getValue(service.targetHeaterCoolerStateId) {
            state.mode = HeaterCoolerState(rawValue: intValue(value))?.label ?? "off"
        } else if let value = getValue(service.targetHeatingCoolingStateId) {
            let raw = intValue(value)
            if service.availableHVACModes != nil {
                let extended: [Int: String] = [0: "off", 1: "heat", 2: "cool", 3: "heat_cool", 4: "dry", 5: "fan_only", 6: "auto"]
                state.mode = extended[raw] ?? "off"
            } else {
                state.mode = TargetThermostatState(rawValue: raw)?.label ?? "off"
            }
        }

        // List of modes the device will actually accept. HA climate emits
        // `availableHVACModes` directly (includes heat_cool, dry, fan_only,
        // etc.); HK Thermostat / HeaterCooler advertise the supported
        // subset of their integer valid-states arrays. Clients should drive
        // the Mode submenu from this list so they never offer a write the
        // device will silently drop.
        state.availableModes = climateAvailableModes(for: service)

        if let value = getValue(service.humidityId) {
            state.humidity = doubleValue(value)
        }
        if let value = getValue(service.hueId) {
            state.hue = doubleValue(value)
        }
        if let value = getValue(service.saturationId) {
            state.saturation = doubleValue(value)
        }
        if let value = getValue(service.lockCurrentStateId) {
            if let strValue = value as? String {
                // HA sends raw state strings: "locked", "unlocked", "locking", "unlocking", "jammed"
                state.locked = strValue == "locked"
            } else {
                state.locked = LockState(rawValue: intValue(value))?.isLocked ?? false
            }
        }
        if let value = getValue(service.currentDoorStateId) {
            state.doorState = DoorState(rawValue: intValue(value))?.label ?? "stopped"
        }
        if let value = getValue(service.rotationSpeedId) {
            state.speed = doubleValue(value)
        }
        // Expose the rotation-speed scale so clients can render presets and
        // captions correctly — HomeKit fans can override the default 0–100
        // range (e.g. 0–6 on stepped ceiling fans).
        if service.rotationSpeedId != nil {
            state.speedMin = service.rotationSpeedMin
            state.speedMax = service.rotationSpeedMax
        }
        if let value = getValue(service.securitySystemCurrentStateId) {
            if let strValue = value as? String {
                // HA sends raw state strings: armed_home, armed_away, armed_night, disarmed, triggered, etc.
                state.securityState = strValue
            } else {
                state.securityState = SecuritySystemState(rawValue: intValue(value))?.label ?? "disarmed"
            }
        }

        // Check if state has any values. speedMin/speedMax are metadata
        // alongside `speed`, so we don't count them on their own.
        let hasState = state.on != nil || state.brightness != nil || state.position != nil ||
                       state.temperature != nil || state.targetTemperature != nil ||
                       state.heatingThreshold != nil || state.coolingThreshold != nil ||
                       state.mode != nil ||
                       state.humidity != nil || state.hue != nil || state.saturation != nil ||
                       state.locked != nil || state.doorState != nil || state.speed != nil ||
                       state.securityState != nil

        return ServiceInfoResponse(
            name: service.name,
            type: serviceTypeLabel(service.serviceType),
            icon: IconResolver.iconName(for: service),
            reachable: accessory?.isReachable ?? false,
            room: roomName,
            state: hasState ? state : nil
        )
    }

    private func buildDebugService(_ service: ServiceData, in data: MenuData, engine: ActionEngine) -> DebugServiceResponse {
        let roomLookup = data.roomLookup()
        let accessory = data.accessories.first { $0.services.contains(where: { $0.uniqueIdentifier == service.uniqueIdentifier }) }
        let roomName = accessory?.roomIdentifier.flatMap { roomLookup[$0] }

        // Build characteristics dictionary
        var chars: [String: CharacteristicDebugInfo] = [:]

        func addChar(_ name: String, _ idString: String?) {
            guard let idStr = idString, let uuid = UUID(uuidString: idStr) else { return }
            let value = engine.bridge?.getCharacteristicValue(identifier: uuid)
            chars[name] = CharacteristicDebugInfo(id: idStr, value: AnyEncodable(value))
        }

        // Power/Active
        addChar("powerState", service.powerStateId)
        addChar("active", service.activeId)

        // Light characteristics
        addChar("brightness", service.brightnessId)
        addChar("hue", service.hueId)
        addChar("saturation", service.saturationId)
        addChar("colorTemperature", service.colorTemperatureId)

        // Temperature
        addChar("currentTemperature", service.currentTemperatureId)
        addChar("targetTemperature", service.targetTemperatureId)

        // Thermostat modes
        addChar("heatingCoolingState", service.heatingCoolingStateId)
        addChar("targetHeatingCoolingState", service.targetHeatingCoolingStateId)

        // HeaterCooler (AC)
        addChar("currentHeaterCoolerState", service.currentHeaterCoolerStateId)
        addChar("targetHeaterCoolerState", service.targetHeaterCoolerStateId)
        addChar("coolingThresholdTemperature", service.coolingThresholdTemperatureId)
        addChar("heatingThresholdTemperature", service.heatingThresholdTemperatureId)

        // Lock
        addChar("lockCurrentState", service.lockCurrentStateId)
        addChar("lockTargetState", service.lockTargetStateId)

        // Position (blinds)
        addChar("currentPosition", service.currentPositionId)
        addChar("targetPosition", service.targetPositionId)

        // Humidity
        addChar("humidity", service.humidityId)

        // Motion
        addChar("motionDetected", service.motionDetectedId)

        // Fan
        addChar("rotationSpeed", service.rotationSpeedId)

        // Garage door
        addChar("currentDoorState", service.currentDoorStateId)
        addChar("targetDoorState", service.targetDoorStateId)
        addChar("obstructionDetected", service.obstructionDetectedId)

        // Contact sensor
        addChar("contactSensorState", service.contactSensorStateId)

        // Humidifier/Dehumidifier
        addChar("currentHumidifierDehumidifierState", service.currentHumidifierDehumidifierStateId)
        addChar("targetHumidifierDehumidifierState", service.targetHumidifierDehumidifierStateId)
        addChar("humidifierThreshold", service.humidifierThresholdId)
        addChar("dehumidifierThreshold", service.dehumidifierThresholdId)

        // Air Purifier
        addChar("currentAirPurifierState", service.currentAirPurifierStateId)
        addChar("targetAirPurifierState", service.targetAirPurifierStateId)

        // Valve
        addChar("inUse", service.inUseId)
        addChar("setDuration", service.setDurationId)
        addChar("remainingDuration", service.remainingDurationId)

        // Security System
        addChar("securitySystemCurrentState", service.securitySystemCurrentStateId)
        addChar("securitySystemTargetState", service.securitySystemTargetStateId)

        // Build limits
        let limits = ServiceLimits(
            colorTemperatureMin: service.colorTemperatureMin,
            colorTemperatureMax: service.colorTemperatureMax,
            rotationSpeedMin: service.rotationSpeedMin,
            rotationSpeedMax: service.rotationSpeedMax,
            valveType: service.valveTypeValue
        )

        return DebugServiceResponse(
            name: service.name,
            accessoryName: service.accessoryName,
            serviceType: service.serviceType,
            serviceTypeLabel: serviceTypeLabel(service.serviceType),
            serviceId: service.uniqueIdentifier,
            reachable: accessory?.isReachable ?? false,
            room: roomName,
            roomId: service.roomIdentifier,
            characteristics: chars.isEmpty ? nil : chars,
            limits: limits.isEmpty ? nil : limits
        )
    }
}
