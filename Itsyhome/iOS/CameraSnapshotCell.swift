//
//  CameraSnapshotCell.swift
//  Itsyhome
//
//  Collection view cell for camera snapshots
//

import UIKit
import HomeKit

class CameraSnapshotCell: UICollectionViewCell {

    static let reuseId = "CameraSnapshotCell"

    let cameraView = HMCameraView()
    let snapshotImageView = UIImageView()
    private let nameLabel = UILabel()
    private let timestampLabel = UILabel()
    private var overlayStack: UIStackView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        contentView.layer.cornerRadius = 6
        contentView.clipsToBounds = true

        cameraView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.isUserInteractionEnabled = false
        contentView.addSubview(cameraView)

        snapshotImageView.translatesAutoresizingMaskIntoConstraints = false
        snapshotImageView.contentMode = .scaleAspectFill
        snapshotImageView.clipsToBounds = true
        snapshotImageView.isHidden = true
        contentView.addSubview(snapshotImageView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        nameLabel.layer.shadowOpacity = 0.8
        nameLabel.layer.shadowRadius = 2
        contentView.addSubview(nameLabel)

        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        timestampLabel.textColor = .white
        timestampLabel.layer.shadowColor = UIColor.black.cgColor
        timestampLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        timestampLabel.layer.shadowOpacity = 0.8
        timestampLabel.layer.shadowRadius = 2
        timestampLabel.textAlignment = .right
        contentView.addSubview(timestampLabel)

        overlayStack = UIStackView()
        overlayStack.axis = .horizontal
        overlayStack.spacing = 4
        overlayStack.alignment = .center
        overlayStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlayStack)

        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            snapshotImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            snapshotImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            snapshotImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            snapshotImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            nameLabel.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor, constant: 6),

            timestampLabel.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 4),
            timestampLabel.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor, constant: -6),

            overlayStack.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor, constant: 4),
            overlayStack.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: -4)
        ])
    }

    func configure(name: String) {
        nameLabel.text = name
    }

    func configureForHA(image: UIImage?) {
        cameraView.isHidden = true
        snapshotImageView.isHidden = false
        snapshotImageView.image = image
    }

    func configureForHomeKit() {
        cameraView.isHidden = false
        snapshotImageView.isHidden = true
        snapshotImageView.image = nil
    }

    func updateTimestamp(since date: Date?) {
        guard let date = date else {
            timestampLabel.text = nil
            return
        }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            timestampLabel.text = "\(seconds)s"
        } else {
            timestampLabel.text = "\(seconds / 60)m"
        }
    }

    func configureOverlays(items: [(characteristic: HMCharacteristic, name: String, serviceType: String)], target: AnyObject, action: Selector) {
        overlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for item in items {
            let pill = createGridPill(characteristic: item.characteristic, name: item.name, serviceType: item.serviceType, target: target, action: action)
            overlayStack.addArrangedSubview(pill)
        }
    }

    func updatePillStates(items: [(characteristic: HMCharacteristic, name: String, serviceType: String)]) {
        for (index, pill) in overlayStack.arrangedSubviews.enumerated() {
            guard index < items.count else { break }
            let isOn = characteristicIsOn(items[index].characteristic)
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
    }

    private func createGridPill(characteristic: HMCharacteristic, name: String, serviceType: String, target: AnyObject, action: Selector) -> UIView {
        let pill = UIView()
        pill.layer.cornerRadius = 12
        pill.translatesAutoresizingMaskIntoConstraints = false

        let iconImage = iconForType(serviceType)
        let iconView = UIImageView(image: iconImage)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 1
        pill.addSubview(iconView)

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 2
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: 24),
            iconView.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 3),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -6)
        ])

        let tap = UITapGestureRecognizer(target: target, action: action)
        pill.addGestureRecognizer(tap)
        pill.isUserInteractionEnabled = true

        objc_setAssociatedObject(pill, &CameraAssociatedKeys.characteristic, characteristic, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let isOn = characteristicIsOn(characteristic)
        if isOn {
            pill.backgroundColor = UIColor(white: 1.0, alpha: 0.85)
            iconView.tintColor = .black
            label.textColor = .black
        } else {
            pill.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
            iconView.tintColor = .white
            label.textColor = .white
        }

        return pill
    }

    private func characteristicIsOn(_ characteristic: HMCharacteristic) -> Bool {
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

    private func iconForType(_ type: String) -> UIImage? {
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

    // MARK: - HA overlay support

    func configureHAOverlays(items: [(entityId: String, name: String, serviceType: String, isOn: Bool)], target: AnyObject, action: Selector) {
        overlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for item in items {
            let pill = createHAGridPill(entityId: item.entityId, name: item.name, serviceType: item.serviceType, isOn: item.isOn, target: target, action: action)
            overlayStack.addArrangedSubview(pill)
        }
    }

    func updateHAPillStates(items: [(entityId: String, name: String, serviceType: String, isOn: Bool)]) {
        for (index, pill) in overlayStack.arrangedSubviews.enumerated() {
            guard index < items.count else { break }
            let isOn = items[index].isOn
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
    }

    private func createHAGridPill(entityId: String, name: String, serviceType: String, isOn: Bool, target: AnyObject, action: Selector) -> UIView {
        let pill = UIView()
        pill.layer.cornerRadius = 12
        pill.translatesAutoresizingMaskIntoConstraints = false

        let iconImage = iconForType(serviceType)
        let iconView = UIImageView(image: iconImage)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tag = 1
        pill.addSubview(iconView)

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 2
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(equalToConstant: 24),
            iconView.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 3),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -6)
        ])

        let tap = UITapGestureRecognizer(target: target, action: action)
        pill.addGestureRecognizer(tap)
        pill.isUserInteractionEnabled = true

        objc_setAssociatedObject(pill, &CameraAssociatedKeys.haEntityId, entityId, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        if isOn {
            pill.backgroundColor = UIColor(white: 1.0, alpha: 0.85)
            iconView.tintColor = .black
            label.textColor = .black
        } else {
            pill.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
            iconView.tintColor = .white
            label.textColor = .white
        }

        return pill
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cameraView.cameraSource = nil
        cameraView.isHidden = false
        snapshotImageView.image = nil
        snapshotImageView.isHidden = true
        nameLabel.text = nil
        timestampLabel.text = nil
        overlayStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}
