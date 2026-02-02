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

// MARK: - Reachability support

/// Protocol for menu items that can show device reachability state.
/// Provides default implementation that dims the view when unreachable.
protocol ReachabilityUpdatableMenuItem: ReachabilityUpdatable, NSMenuItem {
    var serviceData: ServiceData { get }
}

extension ReachabilityUpdatableMenuItem {
    var serviceIdentifier: UUID? {
        UUID(uuidString: serviceData.uniqueIdentifier)
    }

    func setReachable(_ isReachable: Bool) {
        view?.alphaValue = isReachable ? 1.0 : 0.4
        setControlsEnabled(isReachable, in: view)
    }

    private func setControlsEnabled(_ enabled: Bool, in view: NSView?) {
        guard let view = view else { return }
        for subview in view.subviews {
            if let control = subview as? NSControl {
                control.isEnabled = enabled
            }
            setControlsEnabled(enabled, in: subview)
        }
    }
}

// MARK: - Scene icon inference

enum SceneIconInference {
    /// Get icon for a scene - delegates to PhosphorIcon for consistent iconography
    static func icon(for sceneName: String) -> NSImage? {
        PhosphorIcon.iconForScene(sceneName)
    }
}

// MARK: - Home Menu Item

class HomeMenuItem: NSMenuItem {
    let home: HomeInfo

    init(home: HomeInfo, target: AnyObject?, action: Selector?) {
        self.home = home
        super.init(title: home.name, action: action, keyEquivalent: "")
        self.target = target
        self.image = PhosphorIcon.icon("house", filled: home.isPrimary)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
