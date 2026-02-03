//
//  StartupLogger.swift
//  macOSBridge
//
//  Startup diagnostics logging — set enabled to false to silence
//

import os.log

enum StartupLogger {

    static let enabled = false

    private static let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "Startup")

    static func log(_ message: String) {
        guard enabled else { return }
        logger.info("[\("macOS", privacy: .public)] \(message, privacy: .public)")
    }

    static func error(_ message: String) {
        guard enabled else { return }
        logger.error("[\("macOS", privacy: .public)] \(message, privacy: .public)")
    }
}
