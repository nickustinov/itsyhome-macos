//
//  HomeKitManager+Motion.swift
//  Itsyhome
//
//  Motion sensor detection on camera accessories
//

import Foundation
import HomeKit
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "Motion")

extension HomeKitManager {

    // MARK: - Motion subscription

    /// Subscribe to motion sensor notifications on camera accessories
    func subscribeToMotionEvents() {
        guard let home = selectedHome else { return }

        for accessory in home.accessories {
            guard !(accessory.cameraProfiles ?? []).isEmpty else { continue }

            let serviceTypes = accessory.services.map { $0.serviceType }
            let hasMotionService = serviceTypes.contains(ServiceTypes.motionSensor)
            logger.info("Camera \(accessory.name, privacy: .public): \(accessory.services.count) services, hasMotionSensor=\(hasMotionService)")
            for service in accessory.services {
                logger.debug("  Service: \(service.name, privacy: .public) type=\(service.serviceType, privacy: .public)")
            }

            for service in accessory.services where service.serviceType == ServiceTypes.motionSensor {
                guard let motionChar = service.characteristics.first(where: {
                    $0.characteristicType == HMCharacteristicTypeMotionDetected
                }) else { continue }

                motionChar.enableNotification(true) { error in
                    if let error {
                        logger.error("Failed to subscribe to motion events on \(accessory.name, privacy: .public): \(error.localizedDescription)")
                    } else {
                        logger.info("Subscribed to motion events on \(accessory.name, privacy: .public)")
                    }
                }
            }
        }
    }

    // MARK: - Motion event handling

    func handleMotionEventIfNeeded(accessory: HMAccessory, service: HMService, characteristic: HMCharacteristic) -> Bool {
        guard service.serviceType == ServiceTypes.motionSensor,
              characteristic.characteristicType == HMCharacteristicTypeMotionDetected else {
            return false
        }

        let motionDetected = characteristic.value as? Bool ?? false
        guard motionDetected else { return true }  // Only trigger on motion start

        guard !(accessory.cameraProfiles ?? []).isEmpty else { return true }  // Only camera accessories

        let cameraId = accessory.uniqueIdentifier
        logger.info("Motion detected on camera \(accessory.name, privacy: .public)")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Notify macOS side to open the camera panel
            self.macOSDelegate?.showCameraPanelForMotion(cameraIdentifier: cameraId)

            // Store pending camera ID for CameraViewController to stream on show
            self.pendingDoorbellCameraId = cameraId

            // If CameraViewController is already visible, notify it directly
            NotificationCenter.default.post(
                name: .doorbellRang,
                object: nil,
                userInfo: ["cameraIdentifier": cameraId]
            )
        }

        return true
    }
}
