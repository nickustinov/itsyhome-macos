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
        case HMServiceTypeLightbulb: name = "lightbulb.fill"
        case HMServiceTypeSwitch: name = "power"
        case HMServiceTypeOutlet: name = "poweroutlet.type.b.fill"
        case HMServiceTypeGarageDoorOpener: name = "door.garage.closed"
        case HMServiceTypeLockMechanism: name = "lock.fill"
        default: name = "bolt.fill"
        }
        return UIImage(systemName: name)?.withRenderingMode(.alwaysTemplate)
    }
}
