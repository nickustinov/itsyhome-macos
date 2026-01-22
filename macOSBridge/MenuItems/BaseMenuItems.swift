//
//  BaseMenuItems.swift
//  macOSBridge
//
//  Basic menu item types
//

import AppKit

// MARK: - Local change notification

protocol LocalChangeNotifiable: NSMenuItem {}

extension LocalChangeNotifiable {
    func notifyLocalChange(characteristicId: UUID, value: Any) {
        NotificationCenter.default.post(
            name: .characteristicDidChangeLocally,
            object: self,
            userInfo: ["characteristicId": characteristicId, "value": value]
        )
    }
}

// MARK: - Home Menu Item

class HomeMenuItem: NSMenuItem {
    let home: HomeInfo

    init(home: HomeInfo, target: AnyObject?, action: Selector?) {
        self.home = home
        super.init(title: home.name, action: action, keyEquivalent: "")
        self.target = target
        self.image = NSImage(systemSymbolName: home.isPrimary ? "house.fill" : "house", accessibilityDescription: nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
