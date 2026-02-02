//
//  Protocols.swift
//  macOSBridge
//
//  Protocols for menu items and characteristic updates
//

import Foundation

// MARK: - Protocols for menu items

protocol CharacteristicUpdatable {
    func updateValue(for characteristicId: UUID, value: Any, isLocalChange: Bool)
}

protocol CharacteristicRefreshable {
    var characteristicIdentifiers: [UUID] { get }
}

protocol ReachabilityUpdatable {
    var serviceIdentifier: UUID? { get }
    func setReachable(_ isReachable: Bool)
}

// MARK: - Local UI sync

extension Notification.Name {
    /// Posted when a menu item locally changes a characteristic value.
    /// userInfo contains "characteristicId" (UUID) and "value" (Any).
    static let characteristicDidChangeLocally = Notification.Name("characteristicDidChangeLocally")
}
