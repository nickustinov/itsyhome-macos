//
//  SimpleHeightContainer.swift
//  macOSBridge
//
//  Container with an updateable fixed height, used to host tables inside the
//  settings stack view without recreating them on every data change.
//

import AppKit

class SimpleHeightContainer: NSView {

    private var heightConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint?.isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setHeight(_ height: CGFloat) {
        heightConstraint?.constant = height
    }
}
