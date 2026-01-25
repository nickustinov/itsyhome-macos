//
//  CameraPanelManager.swift
//  macOSBridge
//
//  Manages the camera panel window and its menu bar status item
//

import AppKit

protocol CameraPanelManagerDelegate: AnyObject {
    func cameraPanelManagerOpenCameraWindow(_ manager: CameraPanelManager)
    func cameraPanelManagerSetCameraWindowHidden(_ manager: CameraPanelManager, hidden: Bool)
}

final class CameraPanelManager {

    // MARK: - Properties

    private var cameraStatusItem: NSStatusItem?
    private var cameraPanelWindow: NSWindow?
    private var cameraPanelSize: NSSize = NSSize(width: 300, height: 300)
    private var isCameraPanelOpening = false
    private var pendingCameraPanelShow = false
    private var clickOutsideMonitor: Any?
    private var localClickMonitor: Any?
    private var cameraPanelPollTimer: DispatchSourceTimer?
    private var cameraWindowObserver: NSObjectProtocol?

    weak var delegate: CameraPanelManagerDelegate?

    // MARK: - Public API

    func setupCameraStatusItem(hasCameras: Bool) {
        print("[Camera] setupCameraStatusItem called with hasCameras: \(hasCameras)")
        if hasCameras {
            if cameraStatusItem == nil {
                print("[Camera] Creating new camera status item")
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                if let button = item.button {
                    let pluginBundle = Bundle(for: CameraPanelManager.self)
                    if let icon = pluginBundle.image(forResource: "CameraMenuBarIcon") {
                        icon.isTemplate = true
                        button.image = icon
                        print("[Camera] Set custom camera icon")
                    } else {
                        button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Cameras")
                        button.image?.isTemplate = true
                        print("[Camera] Set fallback video.fill icon")
                    }
                    button.action = #selector(cameraStatusItemClicked)
                    button.target = self
                }
                cameraStatusItem = item
                print("[Camera] Camera status item created successfully")
            } else {
                print("[Camera] Camera status item already exists")
            }
        } else {
            if let item = cameraStatusItem {
                print("[Camera] Removing camera status item")
                NSStatusBar.system.removeStatusItem(item)
                cameraStatusItem = nil
            } else {
                print("[Camera] No camera status item to remove")
            }
        }
    }

    func dismissCameraPanel() {
        removeClickOutsideMonitor()
        cameraPanelWindow?.orderOut(nil)
        delegate?.cameraPanelManagerSetCameraWindowHidden(self, hidden: true)
        cameraStatusItem?.button?.highlight(false)
    }

    var isPanelVisible: Bool {
        cameraPanelWindow?.isVisible == true
    }

    func resizeCameraPanel(width: CGFloat, height: CGFloat, animated: Bool) {
        cameraPanelSize = NSSize(width: width, height: height)
        guard let window = cameraPanelWindow else { return }

        // Enable resizing and moving only in stream mode (wider than grid)
        let isStreamMode = width > 400
        if isStreamMode {
            window.styleMask.insert(.resizable)
            window.isMovable = true
            window.isMovableByWindowBackground = true
            // 16:9 aspect ratio constraints
            window.minSize = NSSize(width: 400, height: 225)
            window.maxSize = NSSize(width: 1200, height: 675)
            window.aspectRatio = NSSize(width: 16, height: 9)
        } else {
            window.styleMask.remove(.resizable)
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.minSize = NSSize(width: width, height: height)
            window.maxSize = NSSize(width: width, height: height)
        }

        guard window.isVisible else { return }
        positionCameraPanelWithSize(window, width: width, height: height, animate: animated)
    }

    // MARK: - Status Item Action

    @objc private func cameraStatusItemClicked() {
        if let existing = cameraPanelWindow, existing.isVisible {
            dismissCameraPanel()
            return
        }

        if cameraPanelWindow != nil {
            showCameraPanel()
            return
        }

        if isCameraPanelOpening {
            return
        }

        isCameraPanelOpening = true
        pendingCameraPanelShow = true
        delegate?.cameraPanelManagerOpenCameraWindow(self)
        setupCameraPanelWindow()
    }

    // MARK: - Panel Window Management

    private func showCameraPanel() {
        guard let panel = cameraPanelWindow,
              cameraStatusItem?.button?.window != nil else { return }
        positionCameraPanelWithSize(panel, width: cameraPanelSize.width, height: cameraPanelSize.height)
        delegate?.cameraPanelManagerSetCameraWindowHidden(self, hidden: false)
        panel.alphaValue = 1.0
        panel.makeKeyAndOrderFront(nil)
        setupClickOutsideMonitor()
        // Re-apply highlight after mouse event completes (system resets it on mouseUp)
        DispatchQueue.main.async {
            self.cameraStatusItem?.button?.highlight(true)
        }
    }

    private func setupCameraPanelWindow() {
        // Register notification observer to catch window as early as possible
        cameraWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let window = notification.object as? NSWindow,
                  window.title == "Cameras",
                  self.cameraPanelWindow == nil else { return }
            self.configureCameraPanelWindow(window)
        }

        // Also poll aggressively (every 5ms) as a fallback
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(5))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.cameraPanelWindow == nil else {
                self?.stopCameraPanelPolling()
                return
            }
            if let window = NSApp.windows.first(where: { $0.title == "Cameras" }) {
                self.configureCameraPanelWindow(window)
            }
        }
        timer.resume()
        cameraPanelPollTimer = timer

        // Safety timeout — stop polling after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.stopCameraPanelPolling()
        }
    }

    private func stopCameraPanelPolling() {
        cameraPanelPollTimer?.cancel()
        cameraPanelPollTimer = nil
        if let observer = cameraWindowObserver {
            NotificationCenter.default.removeObserver(observer)
            cameraWindowObserver = nil
        }
    }

    private func configureCameraPanelWindow(_ cameraWindow: NSWindow) {
        stopCameraPanelPolling()

        // Immediately hide to prevent flash
        cameraWindow.alphaValue = 0
        cameraWindow.orderOut(nil)

        cameraPanelWindow = cameraWindow

        cameraWindow.titlebarAppearsTransparent = true
        cameraWindow.titleVisibility = .hidden
        cameraWindow.toolbar = nil
        cameraWindow.standardWindowButton(.closeButton)?.isHidden = true
        cameraWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        cameraWindow.standardWindowButton(.zoomButton)?.isHidden = true
        cameraWindow.styleMask.insert(.fullSizeContentView)

        cameraWindow.isMovable = false
        cameraWindow.level = .popUpMenu
        cameraWindow.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        cameraWindow.hasShadow = true
        cameraWindow.isOpaque = false

        cameraWindow.contentView?.wantsLayer = true
        cameraWindow.contentView?.layer?.cornerRadius = 10
        cameraWindow.contentView?.layer?.masksToBounds = true

        // Window stays hidden — will be shown by showCameraPanel() on user click
        isCameraPanelOpening = false
        if pendingCameraPanelShow {
            pendingCameraPanelShow = false
            showCameraPanel()
        }
    }

    private func positionCameraPanelWithSize(_ window: NSWindow, width: CGFloat, height: CGFloat, animate: Bool = false) {
        guard let button = cameraStatusItem?.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let visibleFrame = screen.visibleFrame

        // Start with centered position
        var x = screenRect.midX - width / 2
        let y = screenRect.minY - height - 4

        // Clamp to screen edges
        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - width

        x = max(minX, min(x, maxX))

        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: animate)
    }

    // MARK: - Click Outside Monitor

    private func setupClickOutsideMonitor() {
        removeClickOutsideMonitor()

        let dismissCheck: () -> Void = { [weak self] in
            guard let self = self else { return }
            let screenPoint = NSEvent.mouseLocation
            if let panel = self.cameraPanelWindow, panel.frame.contains(screenPoint) {
                return
            }
            if let button = self.cameraStatusItem?.button, let btnWindow = button.window {
                let btnRect = button.convert(button.bounds, to: nil)
                let btnScreenRect = btnWindow.convertToScreen(btnRect)
                if btnScreenRect.contains(screenPoint) {
                    return
                }
            }
            self.dismissCameraPanel()
        }

        // Catch clicks outside the app
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            dismissCheck()
        }

        // Catch clicks on other windows within the app (e.g. settings window)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.cameraPanelWindow?.isVisible == true else { return event }
            // Ignore clicks on the camera panel itself or its status bar button
            if event.window == self.cameraPanelWindow { return event }
            if event.window == self.cameraStatusItem?.button?.window { return event }
            self.dismissCameraPanel()
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }
}
