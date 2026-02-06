//
//  CameraViewController+Overlays.swift
//  Itsyhome
//
//  Overlay pill creation and handling
//

import UIKit
import HomeKit

extension CameraViewController {

    // MARK: - Pill size

    enum PillSize {
        case large  // Stream view: matches Back button (28px, font 13)
        case small  // Grid view: compact (24px, font 10)
    }

    // MARK: - Pill creation

    func createOverlayPill(characteristic: HMCharacteristic, name: String, serviceType: String, size: PillSize) -> UIView {
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false

        let isLarge = size == .large
        let pillHeight: CGFloat = isLarge ? 28 : 24
        let iconSize: CGFloat = isLarge ? 14 : 12
        let fontSize: CGFloat = isLarge ? 13 : 10
        let leadingPad: CGFloat = isLarge ? 10 : 6
        let trailingPad: CGFloat = isLarge ? 12 : 6
        let iconLabelGap: CGFloat = isLarge ? 4 : 3

        pill.layer.cornerRadius = pillHeight / 2

        let iconImage = iconForServiceType(serviceType)
        let iconView = UIImageView(image: iconImage)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 1
        pill.addSubview(iconView)

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: fontSize, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 2
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: pillHeight),
            iconView.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: leadingPad),
            iconView.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: iconLabelGap),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -trailingPad)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(overlayPillTapped(_:)))
        pill.addGestureRecognizer(tap)
        pill.isUserInteractionEnabled = true

        objc_setAssociatedObject(pill, &CameraAssociatedKeys.characteristic, characteristic, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let isOn = characteristicIsOn(characteristic)
        updatePillState(pill, isOn: isOn)

        return pill
    }

    func updatePillState(_ pill: UIView, isOn: Bool) {
        if isOn {
            pill.backgroundColor = UIColor(white: 1.0, alpha: 0.85)
            if let icon = pill.viewWithTag(1) as? UIImageView { icon.tintColor = .black }
            if let label = pill.viewWithTag(2) as? UILabel { label.textColor = .black }
        } else {
            pill.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
            if let icon = pill.viewWithTag(1) as? UIImageView { icon.tintColor = .white }
            if let label = pill.viewWithTag(2) as? UILabel { label.textColor = .white }
        }
    }

    @objc func overlayPillTapped(_ gesture: UITapGestureRecognizer) {
        guard let pill = gesture.view,
              let characteristic = objc_getAssociatedObject(pill, &CameraAssociatedKeys.characteristic) as? HMCharacteristic else { return }

        let isOn = characteristicIsOn(characteristic)
        let newValue = toggleValue(for: characteristic, currentlyOn: isOn)

        updatePillState(pill, isOn: !isOn)

        characteristic.writeValue(newValue) { [weak self] error in
            DispatchQueue.main.async {
                if error != nil {
                    self?.updatePillState(pill, isOn: isOn)
                } else if characteristic.characteristicType == HMCharacteristicTypeTargetDoorState ||
                          characteristic.characteristicType == HMCharacteristicTypeTargetLockMechanismState {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.readOverlayCharacteristicValues()
                    }
                }
            }
        }
    }

    // MARK: - Characteristic helpers

    func characteristicIsOn(_ characteristic: HMCharacteristic) -> Bool {
        if characteristic.characteristicType == HMCharacteristicTypeTargetDoorState {
            let intVal = (characteristic.value as? NSNumber)?.intValue ?? 1
            return intVal == 0
        }
        if characteristic.characteristicType == HMCharacteristicTypeTargetLockMechanismState {
            let intVal = (characteristic.value as? NSNumber)?.intValue ?? 0
            return intVal == 1
        }
        if let intVal = (characteristic.value as? NSNumber)?.intValue {
            return intVal != 0
        }
        return false
    }

    func toggleValue(for characteristic: HMCharacteristic, currentlyOn: Bool) -> Any {
        if characteristic.characteristicType == HMCharacteristicTypeTargetDoorState {
            return currentlyOn ? 1 : 0
        }
        if characteristic.characteristicType == HMCharacteristicTypeTargetLockMechanismState {
            return currentlyOn ? 0 : 1
        }
        return currentlyOn ? false : true
    }

    func iconForServiceType(_ type: String) -> UIImage? {
        let name: String
        switch type {
        case HMServiceTypeLightbulb, ServiceTypes.lightbulb: name = "lightbulb.fill"
        case HMServiceTypeSwitch, ServiceTypes.switch: name = "power"
        case HMServiceTypeOutlet, ServiceTypes.outlet: name = "poweroutlet.type.b.fill"
        case HMServiceTypeGarageDoorOpener, ServiceTypes.garageDoorOpener: name = "door.garage.closed"
        case HMServiceTypeLockMechanism, ServiceTypes.lock: name = "lock.fill"
        default: name = "bolt.fill"
        }
        return UIImage(systemName: name)?.withRenderingMode(.alwaysTemplate)
    }

    // MARK: - HA overlay pills

    func createHAOverlayPill(entityId: String, name: String, serviceType: String, isOn: Bool, size: PillSize) -> UIView {
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false

        let isLarge = size == .large
        let pillHeight: CGFloat = isLarge ? 28 : 24
        let iconSize: CGFloat = isLarge ? 14 : 12
        let fontSize: CGFloat = isLarge ? 13 : 10
        let leadingPad: CGFloat = isLarge ? 10 : 6
        let trailingPad: CGFloat = isLarge ? 12 : 6
        let iconLabelGap: CGFloat = isLarge ? 4 : 3

        pill.layer.cornerRadius = pillHeight / 2

        let iconImage = iconForServiceType(serviceType)
        let iconView = UIImageView(image: iconImage)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 1
        pill.addSubview(iconView)

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: fontSize, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 2
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: pillHeight),
            iconView.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: leadingPad),
            iconView.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: iconLabelGap),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -trailingPad)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(haOverlayPillTapped(_:)))
        pill.addGestureRecognizer(tap)
        pill.isUserInteractionEnabled = true

        objc_setAssociatedObject(pill, &CameraAssociatedKeys.haEntityId, entityId, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        updatePillState(pill, isOn: isOn)

        return pill
    }

    @objc func haOverlayPillTapped(_ gesture: UITapGestureRecognizer) {
        guard let pill = gesture.view,
              let entityId = objc_getAssociatedObject(pill, &CameraAssociatedKeys.haEntityId) as? String else { return }

        // Find the service to determine its type
        let menuData = cachedMenuData ?? Self.cachedHAMenuData
        guard let menuData = menuData,
              let service = findService(id: entityId, in: menuData) else { return }

        // Determine current state from pill appearance
        let wasOn = pill.backgroundColor == UIColor(white: 1.0, alpha: 0.85)

        // Optimistic update
        updatePillState(pill, isOn: !wasOn)

        // Call HA service to toggle
        toggleHAService(service: service, turnOn: !wasOn) { [weak self] success in
            DispatchQueue.main.async {
                if !success {
                    // Revert on failure
                    self?.updatePillState(pill, isOn: wasOn)
                }
            }
        }
    }

    func toggleHAService(service: ServiceData, turnOn: Bool, completion: @escaping (Bool) -> Void) {
        guard let serverURL = HAAuthManager.shared.serverURL,
              let token = HAAuthManager.shared.accessToken else {
            completion(false)
            return
        }

        // Get the entity ID from ServiceData
        guard let entityId = service.haEntityId else {
            NSLog("[CameraHA] No haEntityId found for service: \(service.name)")
            completion(false)
            return
        }

        // Determine domain and service based on entity ID prefix
        let domain = entityId.components(separatedBy: ".").first ?? "homeassistant"
        let serviceName = haServiceNameForToggle(domain: domain, turnOn: turnOn)

        let serviceURL = serverURL.appendingPathComponent("api/services/\(domain)/\(serviceName)")

        var request = URLRequest(url: serviceURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["entity_id": entityId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                NSLog("[CameraHA] Service call failed: \(error.localizedDescription)")
                completion(false)
                return
            }

            if let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }

    func haServiceNameForToggle(domain: String, turnOn: Bool) -> String {
        switch domain {
        case "light", "switch", "fan":
            return turnOn ? "turn_on" : "turn_off"
        case "cover":
            return turnOn ? "open_cover" : "close_cover"
        case "lock":
            return turnOn ? "unlock" : "lock"
        default:
            return turnOn ? "turn_on" : "turn_off"
        }
    }

    // MARK: - HA stream overlays

    func updateHAStreamOverlays(cameraId: UUID) {
        streamOverlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let items = haOverlayData[cameraId] else { return }

        for item in items {
            let pill = createHAOverlayPill(entityId: item.entityId, name: item.name, serviceType: item.serviceType, isOn: item.isOn, size: .large)
            streamOverlayStack.addArrangedSubview(pill)
        }
    }

    func refreshHAStreamOverlayStates() {
        guard let cameraId = activeHACameraId,
              let items = haOverlayData[cameraId] else { return }

        for (index, pill) in streamOverlayStack.arrangedSubviews.enumerated() {
            guard index < items.count else { break }
            updatePillState(pill, isOn: items[index].isOn)
        }
    }
}
