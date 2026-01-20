//
//  BaseMenuItems.swift
//  macOSBridge
//
//  Basic menu item types
//

import AppKit

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

// MARK: - Scene Menu Item

class SceneMenuItem: NSMenuItem {
    let scene: SceneInfo
    
    init(scene: SceneInfo, target: AnyObject?, action: Selector?) {
        self.scene = scene
        super.init(title: scene.name, action: action, keyEquivalent: "")
        self.target = target
        self.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
