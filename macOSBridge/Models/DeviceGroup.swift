//
//  DeviceGroup.swift
//  macOSBridge
//
//  Model for device groups
//

import Foundation

struct DeviceGroup: Codable, Identifiable {
    let id: String
    var name: String
    var icon: String
    var deviceIds: [String]  // Service unique identifiers
    var roomId: String?  // Room this group belongs to, nil = global group

    init(id: String = UUID().uuidString, name: String, icon: String = "folder", deviceIds: [String] = [], roomId: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.deviceIds = deviceIds
        self.roomId = roomId
    }

    /// Returns true if all devices in the group are of the same type
    func isHomogeneous(in data: MenuData) -> Bool {
        let services = resolveServices(in: data)
        guard let firstType = services.first?.serviceType else { return true }
        return services.allSatisfy { $0.serviceType == firstType }
    }

    /// Returns the common service type if homogeneous, nil otherwise
    func commonServiceType(in data: MenuData) -> String? {
        let services = resolveServices(in: data)
        guard let firstType = services.first?.serviceType else { return nil }
        return services.allSatisfy { $0.serviceType == firstType } ? firstType : nil
    }

    /// Resolves device IDs to actual ServiceData objects
    func resolveServices(in data: MenuData) -> [ServiceData] {
        let allServices = data.accessories.flatMap { $0.services }
        let serviceDict = Dictionary(uniqueKeysWithValues: allServices.map { ($0.uniqueIdentifier, $0) })
        return deviceIds.compactMap { serviceDict[$0] }
    }

    /// Infers an appropriate icon based on the devices in the group
    static func inferIcon(for deviceIds: [String], in data: MenuData) -> String {
        let allServices = data.accessories.flatMap { $0.services }
        let serviceDict = Dictionary(uniqueKeysWithValues: allServices.map { ($0.uniqueIdentifier, $0) })
        let services = deviceIds.compactMap { serviceDict[$0] }

        guard let firstType = services.first?.serviceType else { return "folder" }

        // If homogeneous, use type-specific icon
        if services.allSatisfy({ $0.serviceType == firstType }) {
            switch firstType {
            case ServiceTypes.lightbulb: return "lightbulb"
            case ServiceTypes.switch, ServiceTypes.outlet: return "powerplug"
            case ServiceTypes.fan: return "fan"
            case ServiceTypes.windowCovering: return "blinds.horizontal.closed"
            case ServiceTypes.lock: return "lock"
            case ServiceTypes.thermostat, ServiceTypes.heaterCooler: return "thermometer"
            case ServiceTypes.garageDoorOpener: return "door.garage.closed"
            default: return "folder"
            }
        }

        return "folder"
    }
}
