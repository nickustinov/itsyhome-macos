//
//  HomeAssistantBridge.swift
//  macOSBridge
//
//  Adapter that implements Mac2iOS protocol for Home Assistant
//  This allows menu items to work with Home Assistant using the same interface as HomeKit
//

import Foundation

/// Bridges HomeAssistantPlatform to the Mac2iOS protocol expected by menu items
class HomeAssistantBridge: NSObject, Mac2iOS {

    private let platform: HomeAssistantPlatform

    init(platform: HomeAssistantPlatform) {
        self.platform = platform
        super.init()
    }

    // MARK: - Mac2iOS Protocol

    var homes: [HomeInfo] {
        // Home Assistant doesn't have multiple homes - return a single virtual home
        let homeId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        return [HomeInfo(uniqueIdentifier: homeId, name: "Home Assistant", isPrimary: true)]
    }

    var selectedHomeIdentifier: UUID? {
        get { nil }
        set { }
    }

    var rooms: [RoomInfo] { [] }
    var accessories: [AccessoryInfo] { [] }
    var scenes: [SceneInfo] { [] }

    func reloadHomeKit() {
        platform.reloadData()
    }

    func executeScene(identifier: UUID) {
        platform.executeScene(identifier: identifier)
    }

    func readCharacteristic(identifier: UUID) {
        platform.readCharacteristic(identifier: identifier)
    }

    func writeCharacteristic(identifier: UUID, value: Any) {
        platform.writeCharacteristic(identifier: identifier, value: value)
    }

    func getCharacteristicValue(identifier: UUID) -> Any? {
        return platform.getCharacteristicValue(identifier: identifier)
    }

    func openCameraWindow() {
        // TODO: Implement camera support for HA
    }

    func closeCameraWindow() {
        // TODO: Implement camera support for HA
    }

    func setCameraWindowHidden(_ hidden: Bool) {
        // TODO: Implement camera support for HA
    }

    func getRawHomeKitDump() -> String? {
        return platform.getRawDataDump()
    }
}
