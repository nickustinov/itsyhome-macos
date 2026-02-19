//
//  HomeAssistantPlatform+Delegate.swift
//  Itsyhome
//
//  HomeAssistantClientDelegate conformance
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HomeAssistantPlatform")

// MARK: - HomeAssistantClientDelegate

extension HomeAssistantPlatform: HomeAssistantClientDelegate {
    func clientDidConnect(_ client: HomeAssistantClient) {
        logger.info("Client connected")
    }

    func clientDidDisconnect(_ client: HomeAssistantClient, error: Error?) {
        logger.info("Client disconnected: \(error?.localizedDescription ?? "no error")")
        delegate?.platformDidDisconnect(self)
    }

    func client(_ client: HomeAssistantClient, didReceiveStateChange entityId: String, newState: HAEntityState, oldState: HAEntityState?) {
        logger.debug("State change: \(entityId, privacy: .public) -> \(newState.state)")

        // Update mapper
        mapper.updateState(newState)

        // Clear pending color writes now that HA has confirmed
        if newState.domain == "light" {
            pendingColorLock.withLock {
                pendingHue.removeValue(forKey: entityId)
                pendingSaturation.removeValue(forKey: entityId)
            }
        }

        // Notify delegate of characteristic changes
        let values = mapper.getCharacteristicValues(for: entityId)
        for (uuid, value) in values {
            delegate?.platformDidUpdateCharacteristic(self, identifier: uuid, value: value)
        }

        // Check for doorbell events
        if newState.domain == "event" && newState.deviceClass == "doorbell" {
            // Find associated camera
            if let cameraUUID = findAssociatedCamera(for: entityId) {
                delegate?.platformDidReceiveDoorbellEvent(self, cameraIdentifier: cameraUUID)
            }
        }
    }

    func client(_ client: HomeAssistantClient, didReceiveEvent event: HAEvent) {
        // Handle other event types if needed
    }

    func client(_ client: HomeAssistantClient, didEncounterError error: Error) {
        delegate?.platformDidEncounterError(self, message: error.localizedDescription)
    }

    private func findAssociatedCamera(for doorbellEntityId: String) -> UUID? {
        // Try to find camera with similar name/device
        let menuData = mapper.generateMenuData()
        for camera in menuData.cameras {
            // Simple heuristic: camera name contains doorbell-related terms
            // or is from the same device
            // This is a simplification - real implementation would check device associations
            return UUID(uuidString: camera.uniqueIdentifier)
        }
        return nil
    }
}
