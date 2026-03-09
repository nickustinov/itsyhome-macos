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
            for cameraUUID in findAssociatedCameras(for: entityId) {
                delegate?.platformDidReceiveDoorbellEvent(self, cameraIdentifier: cameraUUID)
            }
        }

        // Check for motion events (binary_sensor with device_class "motion" turning on)
        if newState.domain == "binary_sensor" && newState.deviceClass == "motion" && newState.state == "on" {
            for cameraUUID in findAssociatedCameras(for: entityId) {
                delegate?.platformDidReceiveMotionEvent(self, cameraIdentifier: cameraUUID)
            }
        }
    }

    func client(_ client: HomeAssistantClient, didReceiveEvent event: HAEvent) {
        // Handle other event types if needed
    }

    func client(_ client: HomeAssistantClient, didEncounterError error: Error) {
        delegate?.platformDidEncounterError(self, message: error.localizedDescription)
    }

    private func findAssociatedCameras(for entityId: String) -> [UUID] {
        mapper.findCamerasOnSameDevice(as: entityId)
    }
}
