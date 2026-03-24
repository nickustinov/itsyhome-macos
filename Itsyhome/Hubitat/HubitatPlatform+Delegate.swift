//
//  HubitatPlatform+Delegate.swift
//  Itsyhome
//
//  HubitatClientDelegate conformance
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "HubitatPlatform")

// MARK: - HubitatClientDelegate

extension HubitatPlatform: HubitatClientDelegate {

    func clientDidConnect(_ client: HubitatClient) {
        logger.info("Client connected")
    }

    func clientDidDisconnect(_ client: HubitatClient, error: Error?) {
        logger.info("Client disconnected: \(error?.localizedDescription ?? "no error")")
        delegate?.platformDidDisconnect(self)
    }

    func client(_ client: HubitatClient, didReceiveDeviceEvent event: HubitatEvent) {
        guard let deviceId = event.deviceId else { return }

        mapper.updateDeviceAttribute(deviceId: deviceId, attributeName: event.name, value: event.value)

        let values = mapper.getCharacteristicValues(for: deviceId)
        for (uuid, value) in values {
            delegate?.platformDidUpdateCharacteristic(self, identifier: uuid, value: value)
        }
    }

    func client(_ client: HubitatClient, didEncounterError error: Error) {
        logger.error("Client error: \(error.localizedDescription)")
        delegate?.platformDidEncounterError(self, message: error.localizedDescription)
    }
}
