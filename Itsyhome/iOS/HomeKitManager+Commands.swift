//
//  HomeKitManager+Commands.swift
//  Itsyhome
//
//  Mac2iOS protocol implementation for HomeKit commands
//

import Foundation
import HomeKit
import UIKit
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HomeKitManager")

extension HomeKitManager {

    // MARK: - Scene execution

    func executeScene(identifier: UUID) {
        guard let home = selectedHome,
              let actionSet = home.actionSets.first(where: { $0.uniqueIdentifier == identifier }) else { return }

        home.executeActionSet(actionSet) { error in
            if let error = error {
                logger.error("Failed to execute scene: \(error.localizedDescription)")
                // Suppress partial success errors (unreachable devices)
                let hmError = error as NSError
                if hmError.domain == HMErrorDomain && hmError.code == HMError.actionSetExecutionPartialSuccess.rawValue {
                    return
                }
                self.macOSDelegate?.showError(message: "Failed to execute scene: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Characteristic operations

    func readCharacteristic(identifier: UUID) {
        guard let characteristic = findCharacteristic(identifier: identifier) else { return }

        // Check if characteristic is readable
        guard characteristic.properties.contains(HMCharacteristicPropertyReadable) else {
            return
        }

        // Check if accessory is reachable
        guard characteristic.service?.accessory?.isReachable == true else {
            return
        }

        characteristic.readValue { error in
            if error != nil {
                // Silently ignore read failures - device may be temporarily unreachable
                return
            }
            if let value = characteristic.value {
                DispatchQueue.main.async {
                    self.macOSDelegate?.updateCharacteristic(identifier: identifier, value: value)
                }
            }
        }
    }

    func writeCharacteristic(identifier: UUID, value: Any) {
        guard let characteristic = findCharacteristic(identifier: identifier) else {
            logger.error("Characteristic not found: \(identifier)")
            return
        }

        // Silently skip if accessory is not reachable
        let accessoryReachable = characteristic.service?.accessory?.isReachable ?? false
        logger.info("writeCharacteristic: accessory isReachable=\(accessoryReachable)")
        guard accessoryReachable else {
            logger.info("Skipping write - accessory not reachable")
            return
        }

        let metadata = characteristic.metadata
        let format = metadata?.format ?? "unknown"
        let minValue = metadata?.minimumValue
        let maxValue = metadata?.maximumValue
        logger.info("Writing to \(characteristic.characteristicType, privacy: .public): input=\(String(describing: value)) (\(type(of: value))), format=\(format, privacy: .public), range=\(String(describing: minValue))-\(String(describing: maxValue))")

        // Convert value to the format expected by the characteristic
        let convertedValue = convertValueForCharacteristic(value, metadata: metadata)

        logger.info("Converted value: \(String(describing: convertedValue)) (\(type(of: convertedValue)))")

        characteristic.writeValue(convertedValue) { error in
            if let error = error {
                logger.error("Write failed for \(characteristic.characteristicType, privacy: .public): \(error.localizedDescription)")
            } else {
                logger.info("Write succeeded for \(characteristic.characteristicType, privacy: .public)")
            }
        }
    }

    func getCharacteristicValue(identifier: UUID) -> Any? {
        return findCharacteristic(identifier: identifier)?.value
    }

    // MARK: - Value conversion

    private func convertValueForCharacteristic(_ value: Any, metadata: HMCharacteristicMetadata?) -> Any {
        guard let format = metadata?.format else {
            return value
        }

        switch format {
        case HMCharacteristicMetadataFormatFloat:
            if let num = value as? NSNumber {
                return num.floatValue
            } else if let num = value as? Double {
                return Float(num)
            } else if let num = value as? Int {
                return Float(num)
            }
        case HMCharacteristicMetadataFormatInt,
             HMCharacteristicMetadataFormatUInt8,
             HMCharacteristicMetadataFormatUInt16,
             HMCharacteristicMetadataFormatUInt32,
             HMCharacteristicMetadataFormatUInt64:
            if let num = value as? NSNumber {
                return num.intValue
            } else if let num = value as? Double {
                return Int(num)
            } else if let num = value as? Float {
                return Int(num)
            }
        case HMCharacteristicMetadataFormatBool:
            if let num = value as? NSNumber {
                return num.boolValue
            } else if let num = value as? Int {
                return num != 0
            }
        default:
            break
        }

        return value
    }

    // MARK: - Camera window management

    func openCameraWindow() {
        #if targetEnvironment(macCatalyst)
        let activityType = "com.nickustinov.itsyhome.camera"

        // Reuse existing session if available
        let existingSession = UIApplication.shared.openSessions.first { session in
            session.configuration.name == "Camera Configuration"
        }

        print("[CameraPanel] openCameraWindow called, existingSession=\(existingSession != nil)")

        let activity = NSUserActivity(activityType: activityType)
        activity.title = "Cameras"

        UIApplication.shared.requestSceneSessionActivation(
            existingSession,
            userActivity: activity,
            options: nil,
            errorHandler: { error in
                print("[CameraPanel] scene activation error: \(error.localizedDescription)")
            }
        )
        #endif
    }

    func closeCameraWindow() {
        #if targetEnvironment(macCatalyst)
        guard let session = UIApplication.shared.openSessions.first(where: {
            $0.configuration.name == "Camera Configuration"
        }) else { return }
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil, errorHandler: nil)
        #endif
    }

    func setCameraWindowHidden(_ hidden: Bool) {
        #if targetEnvironment(macCatalyst)
        let cameraScenes = UIApplication.shared.connectedScenes.compactMap { scene -> UIWindowScene? in
            guard let windowScene = scene as? UIWindowScene else { return nil }
            guard windowScene.session.configuration.name == "Camera Configuration" else { return nil }
            return windowScene
        }

        for windowScene in cameraScenes {
            for window in windowScene.windows {
                window.isHidden = hidden
            }
        }

        if hidden {
            NotificationCenter.default.post(name: .cameraPanelDidHide, object: nil)
        } else {
            NotificationCenter.default.post(name: .cameraPanelDidShow, object: nil)
        }
        #endif
    }
}
