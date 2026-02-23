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
    private var pendingDoorbellShow = false
    private var pendingDoorbellReveal = false
    private var clickOutsideMonitor: Any?
    private var localClickMonitor: Any?
    private var cameraPanelPollTimer: DispatchSourceTimer?
    private var cameraWindowObserver: NSObjectProtocol?
    private(set) var isPinned = false
    private var isDoorbellMode = false
    private var activeCameraId: UUID?
    private var moveObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var autoCloseTimer: DispatchWorkItem?
    private var autoCloseClickMonitor: Any?

    weak var delegate: CameraPanelManagerDelegate?

    // MARK: - Active camera tracking

    func setActiveCameraId(_ id: UUID) {
        activeCameraId = id
    }

    // MARK: - Frame persistence

    private static let savedFramesKey = "cameraWindowFrames"

    private func savedFrames() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: Self.savedFramesKey) as? [String: String] ?? [:]
    }

    private func saveCurrentFrame() {
        guard let window = cameraPanelWindow,
              let cameraId = activeCameraId else { return }
        var frames = savedFrames()
        frames[cameraId.uuidString] = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frames, forKey: Self.savedFramesKey)
    }

    private func savedFrame(for cameraId: UUID) -> NSRect? {
        guard let frameString = savedFrames()[cameraId.uuidString] else { return nil }
        let rect = NSRectFromString(frameString)
        return rect.isEmpty ? nil : rect
    }

    // MARK: - Public API

    func setupCameraStatusItem(hasCameras: Bool) {
        if hasCameras {
            if cameraStatusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                item.autosaveName = "com.itsyhome.cameras"
                if let button = item.button {
                    let pluginBundle = Bundle(for: CameraPanelManager.self)
                    if let icon = pluginBundle.image(forResource: "CameraMenuBarIcon") {
                        icon.isTemplate = true
                        button.image = icon
                    } else {
                        button.image = PhosphorIcon.fill("video-camera")
                        button.image?.isTemplate = true
                    }
                    button.action = #selector(cameraStatusItemClicked)
                    button.target = self
                }
                cameraStatusItem = item
            }
        } else {
            if let item = cameraStatusItem {
                NSStatusBar.system.removeStatusItem(item)
                cameraStatusItem = nil
            }
        }
    }

    func dismissCameraPanel() {
        cancelAutoCloseTimer()
        activeCameraId = nil
        isPinned = false
        isDoorbellMode = false
        pendingDoorbellReveal = false
        removeClickOutsideMonitor()
        // Reset window size/position before hiding to avoid slide animation on next open
        if let window = cameraPanelWindow {
            cameraPanelSize = NSSize(width: 300, height: 300)
            window.styleMask.remove(.resizable)
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.aspectRatio = NSSize(width: 0, height: 0)
            window.minSize = cameraPanelSize
            window.maxSize = cameraPanelSize
            window.level = .popUpMenu
            positionCameraPanelWithSize(window, width: cameraPanelSize.width, height: cameraPanelSize.height)
        }
        cameraPanelWindow?.orderOut(nil)
        delegate?.cameraPanelManagerSetCameraWindowHidden(self, hidden: true)
        cameraStatusItem?.button?.highlight(false)
    }

    func setCameraPinned(_ pinned: Bool) {
        isPinned = pinned
        guard let window = cameraPanelWindow else { return }

        if pinned {
            removeClickOutsideMonitor()
            window.level = .floating
        } else {
            window.level = .popUpMenu
            if window.isVisible {
                setupClickOutsideMonitor()
            }
        }
    }

    var isPanelVisible: Bool {
        cameraPanelWindow?.isVisible == true
    }

    func showForDoorbell() {
        isDoorbellMode = true

        if let existing = cameraPanelWindow, existing.isVisible {
            // Panel already visible — just pin it and reposition
            setCameraPinned(true)
            positionCameraPanelTopRight(existing, width: cameraPanelSize.width, height: cameraPanelSize.height)
            startAutoCloseTimer()
            return
        }

        if cameraPanelWindow != nil {
            // Window exists but hidden — unhide iOS content, wait for stream resize to reveal
            delegate?.cameraPanelManagerSetCameraWindowHidden(self, hidden: false)
            pendingDoorbellReveal = true
            return
        }

        if isCameraPanelOpening { return }

        isCameraPanelOpening = true
        pendingDoorbellShow = true
        delegate?.cameraPanelManagerOpenCameraWindow(self)
        setupCameraPanelWindow()
    }

    func resizeCameraPanel(width: CGFloat, height: CGFloat, aspectRatio: CGFloat, animated: Bool) {
        // Ignore grid-sized resize while in doorbell mode — the stream dimensions are authoritative
        let isStreamMode = width > 400
        if isDoorbellMode && !isStreamMode {
            return
        }
        cameraPanelSize = NSSize(width: width, height: height)
        guard let window = cameraPanelWindow else { return }

        // Enable resizing and moving only in stream mode (wider than grid)
        if isStreamMode {
            window.styleMask.insert(.resizable)
            window.isMovable = true
            window.isMovableByWindowBackground = true
            // Use the camera's detected aspect ratio for window constraints
            let minWidth: CGFloat = 400
            let maxWidth: CGFloat = 1200
            window.minSize = NSSize(width: minWidth, height: minWidth / aspectRatio)
            window.maxSize = NSSize(width: maxWidth, height: maxWidth / aspectRatio)
            window.aspectRatio = NSSize(width: aspectRatio, height: 1)
        } else {
            activeCameraId = nil
            isDoorbellMode = false
            if isPinned {
                isPinned = false
                window.level = .popUpMenu
            }
            window.styleMask.remove(.resizable)
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.aspectRatio = NSSize(width: 0, height: 0)
            window.minSize = NSSize(width: width, height: height)
            window.maxSize = NSSize(width: width, height: height)
            if window.isVisible {
                setupClickOutsideMonitor()
            }
        }

        if pendingDoorbellReveal && isStreamMode {
            pendingDoorbellReveal = false
            setCameraPinned(true)
            positionCameraPanelTopRight(window, width: width, height: height)
            window.alphaValue = 1.0
            window.makeKeyAndOrderFront(nil)
            setupClickOutsideMonitor()
            cameraStatusItem?.button?.highlight(true)
            startAutoCloseTimer()
            return
        }

        guard window.isVisible else { return }
        if isDoorbellMode {
            positionCameraPanelTopRight(window, width: width, height: height)
        } else if isStreamMode, let cameraId = activeCameraId, let saved = savedFrame(for: cameraId) {
            window.setFrame(saved, display: true, animate: animated)
        } else {
            positionCameraPanelWithSize(window, width: width, height: height, animate: animated)
        }
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

        // Save frame when user moves or resizes the window, cancel auto-close on interaction
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: cameraWindow,
            queue: .main
        ) { [weak self] _ in
            self?.cancelAutoCloseTimer()
            self?.saveCurrentFrame()
        }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: cameraWindow,
            queue: .main
        ) { [weak self] _ in
            self?.cancelAutoCloseTimer()
            self?.saveCurrentFrame()
        }

        // Cancel auto-close when user clicks inside the camera panel
        autoCloseClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return event }
            if event.window == cameraWindow {
                self.cancelAutoCloseTimer()
            }
            return event
        }

        // Window stays hidden — will be shown by showCameraPanel() on user click
        isCameraPanelOpening = false
        if pendingDoorbellShow {
            pendingDoorbellShow = false
            pendingCameraPanelShow = false
            // Don't show yet — keep hidden until stream resize arrives with correct dimensions.
            // Unhide the iOS content so the view controller lifecycle runs (panelDidShow → startStream).
            delegate?.cameraPanelManagerSetCameraWindowHidden(self, hidden: false)
            pendingDoorbellReveal = true
        } else if pendingCameraPanelShow {
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

    private func positionCameraPanelTopRight(_ window: NSWindow, width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let padding: CGFloat = 16
        let x = visibleFrame.maxX - width - padding
        let y = visibleFrame.maxY - height - padding
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    // MARK: - Auto-close timer

    private func startAutoCloseTimer() {
        cancelAutoCloseTimer()
        guard PreferencesManager.shared.doorbellAutoClose else { return }
        let delay = PreferencesManager.shared.doorbellAutoCloseDelay
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissCameraPanel()
        }
        autoCloseTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: workItem)
    }

    private func cancelAutoCloseTimer() {
        autoCloseTimer?.cancel()
        autoCloseTimer = nil
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
