//
//  HomeKitManager+Debug.swift
//  Itsyhome
//
//  Debug utilities for HomeKit data inspection
//

import Foundation
import HomeKit

extension HomeKitManager {

    func getRawHomeKitDump() -> String? {
        guard let home = selectedHome else {
            return "{\"error\":\"No home selected\"}"
        }

        var result: [String: Any] = [
            "homeName": home.name,
            "homeId": home.uniqueIdentifier.uuidString
        ]

        // Dump all accessories with all services and characteristics
        var accessoriesArray: [[String: Any]] = []
        for accessory in home.accessories {
            var accDict: [String: Any] = [
                "name": accessory.name,
                "id": accessory.uniqueIdentifier.uuidString,
                "reachable": accessory.isReachable,
                "room": accessory.room?.name ?? "No Room"
            ]

            var servicesArray: [[String: Any]] = []
            for service in accessory.services {
                var serviceDict: [String: Any] = [
                    "name": service.name,
                    "type": service.serviceType,
                    "id": service.uniqueIdentifier.uuidString
                ]

                // Map service type to readable name
                let typeName = HomeKitTypeNames.serviceName(service.serviceType)
                if !typeName.isEmpty {
                    serviceDict["typeName"] = typeName
                }

                var charsArray: [[String: Any]] = []
                for char in service.characteristics {
                    var charDict: [String: Any] = [
                        "type": char.characteristicType,
                        "id": char.uniqueIdentifier.uuidString
                    ]

                    // Map characteristic type to readable name
                    let charName = HomeKitTypeNames.characteristicName(char.characteristicType)
                    if !charName.isEmpty {
                        charDict["typeName"] = charName
                    }

                    // Only include JSON-serializable values
                    if let value = char.value {
                        charDict = addSerializableValue(value, to: charDict)
                    }

                    if let metadata = char.metadata {
                        charDict = addMetadata(metadata, to: charDict)
                    }

                    let props = char.properties
                    if !props.isEmpty {
                        charDict["properties"] = props
                    }

                    charsArray.append(charDict)
                }

                serviceDict["characteristics"] = charsArray
                servicesArray.append(serviceDict)
            }

            accDict["services"] = servicesArray
            accessoriesArray.append(accDict)
        }

        result["accessories"] = accessoriesArray
        result["accessoryCount"] = home.accessories.count

        // Also include rooms
        result["rooms"] = home.rooms.map { ["name": $0.name, "id": $0.uniqueIdentifier.uuidString] }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return "{\"error\":\"\(error.localizedDescription)\"}"
        }
    }

    // MARK: - Private helpers

    private func addSerializableValue(_ value: Any, to dict: [String: Any]) -> [String: Any] {
        var charDict = dict

        if let data = value as? Data {
            charDict["value"] = data.base64EncodedString()
            charDict["valueType"] = "data"
        } else if let number = value as? NSNumber {
            charDict["value"] = number
        } else if let string = value as? String {
            charDict["value"] = string
        } else if let bool = value as? Bool {
            charDict["value"] = bool
        } else if let array = value as? [Any], JSONSerialization.isValidJSONObject(array) {
            charDict["value"] = array
        } else if let dict = value as? [String: Any], JSONSerialization.isValidJSONObject(dict) {
            charDict["value"] = dict
        } else {
            charDict["value"] = String(describing: value)
            charDict["valueType"] = "unknown"
        }

        return charDict
    }

    private func addMetadata(_ metadata: HMCharacteristicMetadata, to dict: [String: Any]) -> [String: Any] {
        var charDict = dict
        var meta: [String: Any] = [:]

        if let min = metadata.minimumValue {
            meta["min"] = min
        }
        if let max = metadata.maximumValue {
            meta["max"] = max
        }
        if let step = metadata.stepValue {
            meta["step"] = step
        }
        if let format = metadata.format {
            meta["format"] = format
        }
        if let units = metadata.units {
            meta["units"] = units
        }

        if !meta.isEmpty {
            charDict["metadata"] = meta
        }

        return charDict
    }
}
