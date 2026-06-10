//
//  FilePairingStore.swift
//  macOSBridge
//
//  File-backed HAP pairing store so controller pairings survive app restarts.
//  The library's InMemoryPairingStore forgets them every launch, which - with a
//  changing device ID - leaves HomeKit with stale records and forces a re-pair.
//

import Foundation
import HAPSwift
import os.log

/// Persists pairings (controllerIdentifier -> long-term public key) to a JSON
/// file. `Data` encodes as base64 in JSON, so the dictionary is Codable as-is.
/// Methods mirror `InMemoryPairingStore`: synchronous and non-throwing (the
/// actor isolation satisfies the protocol's `async throws` requirements), with
/// disk-write failures logged rather than propagated.
actor FilePairingStore: PairingStore {

    private let fileURL: URL
    private var pairings: [String: Data]
    private let logger = os.Logger(subsystem: "com.nickustinov.itsyhome.macOSBridge", category: "HAP")

    /// Computed (mirrors InMemoryPairingStore) - witnesses the protocol's
    /// `var isPaired: Bool { get async }` via actor isolation.
    var isPaired: Bool { !pairings.isEmpty }

    init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            self.pairings = decoded
        } else {
            self.pairings = [:]
        }
    }

    func store(controllerIdentifier: String, publicKey: Data) async throws {
        pairings[controllerIdentifier] = publicKey
        persist()
    }

    func publicKey(for controllerIdentifier: String) async throws -> Data? {
        pairings[controllerIdentifier]
    }

    func remove(controllerIdentifier: String) async throws {
        pairings.removeValue(forKey: controllerIdentifier)
        persist()
    }

    func listPairings() async throws -> [(identifier: String, publicKey: Data)] {
        pairings.map { (identifier: $0.key, publicKey: $0.value) }
    }

    private func persist() {
        do {
            try JSONEncoder().encode(pairings).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("FilePairingStore persist failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
