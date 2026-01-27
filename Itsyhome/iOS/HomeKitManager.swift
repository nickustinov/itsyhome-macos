//
//  HomeKitManager.swift
//  Itsyhome
//
//  HomeKit manager that implements Mac2iOS protocol
//

import Foundation
import HomeKit
import os.log
import UIKit

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HomeKitManager")

class HomeKitManager: NSObject, Mac2iOS, HMHomeManagerDelegate {

    private static let selectedHomeKey = "selectedHomeIdentifier"

    var homeManager: HMHomeManager?
    private var currentHome: HMHome?

    weak var macOSDelegate: iOS2Mac?

    // MARK: - Cached data (stored properties for thread safety)

    var homes: [HomeInfo] = []
    var rooms: [RoomInfo] = []
    var accessories: [AccessoryInfo] = []
    var scenes: [SceneInfo] = []

    var selectedHome: HMHome? { currentHome }

    var cameraAccessories: [HMAccessory] {
        guard let home = currentHome else { return [] }
        return home.accessories.filter { !($0.cameraProfiles ?? []).isEmpty }
    }

    var selectedHomeIdentifier: UUID? {
        get { currentHome?.uniqueIdentifier }
        set {
            if let id = newValue, let manager = homeManager {
                currentHome = manager.homes.first { $0.uniqueIdentifier == id }
                // Persist the selection
                UserDefaults.standard.set(id.uuidString, forKey: Self.selectedHomeKey)
            } else {
                currentHome = homeManager?.primaryHome ?? homeManager?.homes.first
                UserDefaults.standard.removeObject(forKey: Self.selectedHomeKey)
            }
            fetchDataAndReloadMenu()
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()
        logger.info("HomeKitManager init")

        // Initialize HomeManager
        homeManager = HMHomeManager()
        homeManager?.delegate = self
    }

    // MARK: - Mac2iOS reload

    func reloadHomeKit() {
        fetchDataAndReloadMenu()
    }

    // MARK: - Helper methods

    func findService(identifier: UUID) -> HMService? {
        guard let home = currentHome else { return nil }

        for accessory in home.accessories {
            if let service = accessory.services.first(where: { $0.uniqueIdentifier == identifier }) {
                return service
            }
        }
        return nil
    }

    func findCharacteristic(identifier: UUID) -> HMCharacteristic? {
        guard let home = currentHome else { return nil }

        for accessory in home.accessories {
            for service in accessory.services {
                if let characteristic = service.characteristics.first(where: { $0.uniqueIdentifier == identifier }) {
                    return characteristic
                }
            }
        }
        return nil
    }

    // MARK: - HMHomeManagerDelegate

    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        logger.info("Authorization status: \(status.rawValue)")

        if status.contains(.authorized) {
            logger.info("HomeKit authorized")
        } else if status.contains(.determined) {
            logger.warning("HomeKit not authorized")
            DispatchQueue.main.async {
                self.macOSDelegate?.showError(message: "HomeKit access denied. Enable in System Settings > Privacy & Security > HomeKit")
            }
        }
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        logger.info("homeManagerDidUpdateHomes - count: \(manager.homes.count)")

        // Select home if none selected
        if currentHome == nil {
            // Try to restore previously selected home
            if let savedId = UserDefaults.standard.string(forKey: Self.selectedHomeKey),
               let uuid = UUID(uuidString: savedId),
               let savedHome = manager.homes.first(where: { $0.uniqueIdentifier == uuid }) {
                currentHome = savedHome
                logger.info("Restored home: \(self.currentHome?.name ?? "none", privacy: .public)")
            } else {
                currentHome = manager.primaryHome ?? manager.homes.first
                logger.info("Selected home: \(self.currentHome?.name ?? "none", privacy: .public)")
            }
        }

        fetchDataAndReloadMenu()
    }
}

// MARK: - HMHomeDelegate

extension HomeKitManager: HMHomeDelegate {
    func home(_ home: HMHome, didAdd accessory: HMAccessory) {
        accessory.delegate = self
        fetchDataAndReloadMenu()
    }

    func home(_ home: HMHome, didRemove accessory: HMAccessory) {
        fetchDataAndReloadMenu()
    }

    func home(_ home: HMHome, didAdd room: HMRoom) {
        fetchDataAndReloadMenu()
    }

    func home(_ home: HMHome, didRemove room: HMRoom) {
        fetchDataAndReloadMenu()
    }

    func home(_ home: HMHome, didAdd actionSet: HMActionSet) {
        fetchDataAndReloadMenu()
    }

    func home(_ home: HMHome, didRemove actionSet: HMActionSet) {
        fetchDataAndReloadMenu()
    }
}

// MARK: - HMAccessoryDelegate

extension HomeKitManager: HMAccessoryDelegate {
    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        macOSDelegate?.setReachability(accessoryIdentifier: accessory.uniqueIdentifier, isReachable: accessory.isReachable)
    }

    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        if let value = characteristic.value {
            macOSDelegate?.updateCharacteristic(identifier: characteristic.uniqueIdentifier, value: value)
        }
    }
}
