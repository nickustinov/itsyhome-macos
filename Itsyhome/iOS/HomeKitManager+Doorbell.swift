//
//  HomeKitManager+Doorbell.swift
//  Itsyhome
//
//  Doorbell event detection and subscription
//

import Foundation
import HomeKit
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "Doorbell")

extension Notification.Name {
    static let doorbellRang = Notification.Name("doorbellRang")
}

extension HomeKitManager {

    /// The HAP service type for doorbell (0x121)
    static let doorbellServiceType = "00000121-0000-1000-8000-0026BB765291"

    /// The HAP characteristic type for ProgrammableSwitchEvent (0x73)
    static let programmableSwitchEventType = "00000073-0000-1000-8000-0026BB765291"

    // MARK: - Doorbell subscription

    func subscribeToDoorbellEvents() {
        guard let home = selectedHome else { return }

        for accessory in home.accessories {
            guard !accessory.cameraProfiles.isNilOrEmpty else { continue }

            for service in accessory.services where service.serviceType == Self.doorbellServiceType {
                guard let switchChar = service.characteristics.first(where: {
                    $0.characteristicType == Self.programmableSwitchEventType
                }) else { continue }

                switchChar.enableNotification(true) { error in
                    if let error {
                        logger.error("Failed to subscribe to doorbell events on \(accessory.name, privacy: .public): \(error.localizedDescription)")
                    } else {
                        logger.info("Subscribed to doorbell events on \(accessory.name, privacy: .public)")
                    }
                }
            }
        }
    }

    // MARK: - Doorbell event handling

    func handleDoorbellEventIfNeeded(accessory: HMAccessory, service: HMService, characteristic: HMCharacteristic) -> Bool {
        guard service.serviceType == Self.doorbellServiceType,
              characteristic.characteristicType == Self.programmableSwitchEventType else {
            return false
        }

        let switchValue = characteristic.value as? Int ?? 0
        logger.info("Doorbell rang on \(accessory.name, privacy: .public) (event: \(switchValue))")

        // Only trigger on single press (0)
        guard switchValue == 0 else { return true }

        // Find the camera accessory that owns this doorbell service
        let cameraId = accessory.uniqueIdentifier

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Notify macOS side to open the camera panel (checks preferences + shows panel)
            self.macOSDelegate?.showCameraPanelForDoorbell(cameraIdentifier: cameraId)

            // Only start the stream if doorbell notifications are enabled
            guard UserDefaults.standard.bool(forKey: "doorbellNotifications") else { return }

            // Store pending camera ID for CameraViewController to consume on show
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

// MARK: - Optional collection helper

private extension Optional where Wrapped: Collection {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
