//
//  CameraViewController+Audio.swift
//  Itsyhome
//
//  Audio controls for camera streaming
//

import UIKit
import HomeKit

extension CameraViewController {

    // MARK: - Setup

    func setupAudioControls() {
        audioControlsStack = UIStackView()
        audioControlsStack.axis = .horizontal
        audioControlsStack.spacing = 6
        audioControlsStack.alignment = .center
        audioControlsStack.translatesAutoresizingMaskIntoConstraints = false
        audioControlsStack.isHidden = true
        streamContainerView.addSubview(audioControlsStack)

        NSLayoutConstraint.activate([
            audioControlsStack.trailingAnchor.constraint(equalTo: streamContainerView.trailingAnchor, constant: -8),
            audioControlsStack.bottomAnchor.constraint(equalTo: streamContainerView.bottomAnchor, constant: -8)
        ])

        muteButton = createAudioButton(systemName: "speaker.wave.3.fill")
        muteButton.addTarget(self, action: #selector(muteButtonTapped), for: .touchUpInside)
        audioControlsStack.addArrangedSubview(muteButton)

        talkButton = createAudioButton(systemName: "mic.fill")
        talkButton.addTarget(self, action: #selector(talkButtonTapped), for: .touchUpInside)
        talkButton.isHidden = true
        audioControlsStack.addArrangedSubview(talkButton)
    }

    private func createAudioButton(systemName: String) -> UIButton {
        let button = UIButton(type: .custom)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = UIImage(systemName: systemName, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
        button.backgroundColor = UIColor(white: 0, alpha: 0.5)
        button.layer.cornerRadius = 14
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 28)
        ])

        return button
    }

    // MARK: - Controls

    func updateAudioControls(for accessory: HMAccessory) {
        guard let profile = accessory.cameraProfiles?.first else {
            audioControlsStack.isHidden = true
            return
        }

        microphoneControl = profile.microphoneControl
        speakerControl = profile.speakerControl

        audioControlsStack.isHidden = microphoneControl == nil
        talkButton.isHidden = speakerControl == nil

        isTalking = false
        updateTalkButtonState()
    }

    func updateMuteButtonState() {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconName = isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill"
        let image = UIImage(systemName: iconName, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        muteButton.setImage(image, for: .normal)
    }

    private func updateTalkButtonState() {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconName = isTalking ? "mic.fill" : "mic"
        let color: UIColor = isTalking ? .systemGreen : .white
        let image = UIImage(systemName: iconName, withConfiguration: config)?.withTintColor(color, renderingMode: .alwaysOriginal)
        talkButton.setImage(image, for: .normal)
        talkButton.backgroundColor = isTalking ? UIColor(white: 0, alpha: 0.7) : UIColor(white: 0, alpha: 0.5)
    }

    @objc private func muteButtonTapped() {
        // HA WebRTC audio muting
        if let webrtcClient = webrtcClient {
            isMuted.toggle()
            webrtcClient.setAudioEnabled(!isMuted)
            updateMuteButtonState()
            return
        }

        // HK stream audio muting
        guard let stream = activeStreamControl?.cameraStream else { return }

        let newMuteState = !isMuted
        let newSetting: HMCameraAudioStreamSetting = newMuteState ? .muted : (HMCameraAudioStreamSetting(rawValue: 2) ?? .muted)

        stream.updateAudioStreamSetting(newSetting) { [weak self] error in
            DispatchQueue.main.async {
                guard error == nil else { return }
                self?.isMuted = newMuteState
                self?.updateMuteButtonState()
                if let accessory = self?.activeStreamAccessory {
                    self?.saveMuteSetting(for: accessory, muted: newMuteState)
                }
            }
        }
    }

    @objc private func talkButtonTapped() {
        guard let speakerMuteChar = speakerControl?.mute else { return }

        let newTalkState = !isTalking

        speakerMuteChar.writeValue(!newTalkState) { [weak self] error in
            DispatchQueue.main.async {
                guard error == nil else { return }
                self?.isTalking = newTalkState
                self?.updateTalkButtonState()
            }
        }
    }

    func resetAudioState() {
        microphoneControl = nil
        speakerControl = nil
        isMuted = false
        isTalking = false
        audioControlsStack.isHidden = true
    }

    // MARK: - Preferences

    func saveMuteSetting(for accessory: HMAccessory, muted: Bool) {
        let key = "cameraAudioMuted_\(accessory.uniqueIdentifier.uuidString)"
        UserDefaults.standard.set(muted, forKey: key)
    }

    func loadMuteSetting(for accessory: HMAccessory) -> Bool {
        let key = "cameraAudioMuted_\(accessory.uniqueIdentifier.uuidString)"
        return UserDefaults.standard.bool(forKey: key)
    }
}
