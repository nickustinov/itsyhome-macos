//
//  NetworkLocationManager.swift
//  macOSBridge
//
//  Monitors WiFi SSID changes using CoreWLAN and manages Location Services permission
//

import Foundation
import CoreWLAN
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.nickustinov.itsyhome", category: "NetworkLocationManager")

protocol NetworkLocationManagerDelegate: AnyObject {
    func networkLocationManager(_ manager: NetworkLocationManager, didChangeSSID ssid: String?)
}

final class NetworkLocationManager: NSObject {

    static let shared = NetworkLocationManager()

    static let locationAuthorizationDidChange = Notification.Name("NetworkLocationManagerAuthorizationDidChange")

    weak var delegate: NetworkLocationManagerDelegate?

    private let wifiClient = CWWiFiClient.shared()
    private let locationManager = CLLocationManager()
    private var debounceWorkItem: DispatchWorkItem?
    private var isMonitoring = false

    // MARK: - Public API

    var currentSSID: String? {
        wifiClient.interface()?.ssid()
    }

    var hasLocationPermission: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedAlways || status == .authorized
    }

    var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    func requestLocationPermission() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        guard hasLocationPermission else {
            logger.info("Cannot start SSID monitoring – no location permission")
            return
        }

        logger.info("Starting SSID monitoring")
        isMonitoring = true
        wifiClient.delegate = self

        do {
            try wifiClient.startMonitoringEvent(with: .ssidDidChange)
            logger.info("Registered for SSID change events")
        } catch {
            logger.error("Failed to register for SSID changes: \(error.localizedDescription)")
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        logger.info("Stopping SSID monitoring")
        isMonitoring = false
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        do {
            try wifiClient.stopMonitoringAllEvents()
        } catch {
            logger.error("Failed to stop monitoring: \(error.localizedDescription)")
        }
    }

    /// Re-evaluate current SSID (e.g. after wake or network change)
    func reevaluateSSID() {
        guard isMonitoring else { return }
        handleSSIDChange()
    }

    // MARK: - Private

    private override init() {
        super.init()
    }

    private func handleSSIDChange() {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let ssid = self.currentSSID
            logger.info("SSID changed to: \(ssid ?? "<none>", privacy: .public)")
            self.delegate?.networkLocationManager(self, didChangeSSID: ssid)
        }

        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }
}

// MARK: - CWEventDelegate

extension NetworkLocationManager: CWEventDelegate {
    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        logger.info("SSID change event on interface \(interfaceName, privacy: .public)")
        DispatchQueue.main.async { [weak self] in
            self?.handleSSIDChange()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension NetworkLocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        logger.info("Location authorization changed: \(String(describing: status))")
        NotificationCenter.default.post(name: Self.locationAuthorizationDidChange, object: nil)

        // Start monitoring if permission was just granted while feature is enabled
        if hasLocationPermission && PreferencesManager.shared.networkAutoSwitchEnabled && !isMonitoring {
            startMonitoring()
        }
    }
}
