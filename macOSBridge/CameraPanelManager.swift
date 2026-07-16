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
    /// Last grid-mode size, restored on dismiss so reopening doesn't flash
    /// at a stale stream size (the grid can be wider than a stream now).
    private var lastGridSize: NSSize = NSSize(width: 300, height: 300)
    /// Whether the panel is currently in stream (detail) mode – decides which
    /// frame persistence a user resize belongs to.
    private var isStreamModeActive = false
    /// A resize requested while the user was dragging a corner, applied when
    /// the drag ends (mutating geometry inside a live resize traps).
    private var pendingResize: (width: CGFloat, height: CGFloat, aspectRatio: CGFloat, isStream: Bool, animated: Bool)?

    /// The default grid width computed by the Catalyst side (columns
    /// setting). Persisted so a columns change made while the panel's window
    /// doesn't exist – or in a previous launch – still resets the user's
    /// manual grid size on the next open.
    private static let gridDefaultWidthKey = "cameraPanelGridDefaultWidth"
    private var lastDefaultGridWidth: CGFloat {
        get { UserDefaults.standard.double(forKey: Self.gridDefaultWidthKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.gridDefaultWidthKey) }
    }

    /// User-chosen grid size from a corner drag, persisted across launches.
    private static let gridSizeKey = "cameraPanelGridSize"
    private var savedGridSize: NSSize? {
        get {
            guard let string = UserDefaults.standard.string(forKey: Self.gridSizeKey) else { return nil }
            let size = NSSizeFromString(string)
            return size == .zero ? nil : size
        }
        set {
            if let size = newValue {
                UserDefaults.standard.set(NSStringFromSize(size), forKey: Self.gridSizeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.gridSizeKey)
            }
        }
    }
    private var isCameraPanelOpening = false
    private var pendingCameraPanelShow = false
    private var pendingAutoOpenShow = false
    private var pendingAutoOpenReveal = false
    private var clickOutsideMonitor: Any?
    private var localClickMonitor: Any?
    private var escKeyMonitor: Any?
    private var cameraPanelPollTimer: DispatchSourceTimer?
    private var cameraWindowObserver: NSObjectProtocol?
    private(set) var isPinned = false
    private var isAutoOpenMode = false
    private var activeCameraId: UUID?
    private var moveObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?
    private var liveResizeObserver: NSObjectProtocol?
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
        isAutoOpenMode = false
        pendingAutoOpenReveal = false
        removeDismissMonitors()
        // Reset window size/position before hiding to avoid slide animation on next open
        if let window = cameraPanelWindow {
            cameraPanelSize = lastGridSize
            window.styleMask.remove(.resizable)
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.resizeIncrements = NSSize(width: 1, height: 1)
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
            removeDismissMonitors()
            window.level = .floating
        } else {
            window.level = .popUpMenu
            if window.isVisible {
                setupDismissMonitors()
            }
        }
    }

    var isPanelVisible: Bool {
        cameraPanelWindow?.isVisible == true
    }

    func showForAutoOpen(cameraId: UUID? = nil) {
        if let cameraId = cameraId {
            activeCameraId = cameraId
        }
        isAutoOpenMode = true

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
            pendingAutoOpenReveal = true
            return
        }

        if isCameraPanelOpening { return }

        isCameraPanelOpening = true
        pendingAutoOpenShow = true
        delegate?.cameraPanelManagerOpenCameraWindow(self)
        setupCameraPanelWindow()
    }

    func resizeCameraPanel(width: CGFloat, height: CGFloat, aspectRatio: CGFloat, isStream isStreamMode: Bool, animated: Bool) {
        // Ignore grid-sized resize while in auto-open mode — the stream dimensions are authoritative
        if isAutoOpenMode && !isStreamMode {
            return
        }

        // Never mutate the window (or the mode flag) while the user is
        // dragging a corner – snapshot/aspect-ratio callbacks and doorbell
        // auto-opens can fire mid-drag, and a programmatic setFrame inside
        // AppKit's live-resize event loop traps. The request is applied when
        // the drag ends.
        if let window = cameraPanelWindow, window.inLiveResize {
            pendingResize = (width, height, aspectRatio, isStreamMode, animated)
            return
        }

        isStreamModeActive = isStreamMode

        // The grid honours a user corner-drag over the computed content size,
        // until the default width changes (columns setting) which resets it.
        var width = width
        var height = height
        if !isStreamMode {
            if lastDefaultGridWidth != 0, lastDefaultGridWidth != width {
                savedGridSize = nil
            }
            lastDefaultGridWidth = width
            if let saved = savedGridSize {
                width = saved.width
                height = saved.height
            }
            // The computed content height is unbounded (portrait cameras make
            // very tall rows) but the window must stay within its size
            // restrictions and the screen – setFrame beyond them crashes the
            // Catalyst window.
            width = min(max(width, CameraPanelBounds.minWidth), CameraPanelBounds.maxWidth)
            height = min(max(height, CameraPanelBounds.minHeight), CameraPanelBounds.maxHeight)
        }

        cameraPanelSize = NSSize(width: width, height: height)
        if !isStreamMode {
            lastGridSize = cameraPanelSize
        }
        guard let window = cameraPanelWindow else { return }

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
            isAutoOpenMode = false
            if isPinned {
                isPinned = false
                window.level = .popUpMenu
            }
            // Freely resizable by its corners, but anchored (not movable) –
            // the grid content reflows to whatever size the user drags.
            window.styleMask.insert(.resizable)
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.resizeIncrements = NSSize(width: 1, height: 1)
            window.minSize = NSSize(width: CameraPanelBounds.minWidth, height: CameraPanelBounds.minHeight)
            window.maxSize = NSSize(width: CameraPanelBounds.maxWidth, height: CameraPanelBounds.maxHeight)
            if window.isVisible {
                setupDismissMonitors()
            }
        }

        if pendingAutoOpenReveal && isStreamMode {
            pendingAutoOpenReveal = false
            isAutoOpenMode = false
            setCameraPinned(true)
            if let cameraId = activeCameraId, let saved = savedFrame(for: cameraId) {
                window.setFrame(saved, display: true)
            } else {
                positionCameraPanelTopRight(window, width: width, height: height)
            }
            window.alphaValue = 1.0
            window.makeKeyAndOrderFront(nil)
            setupDismissMonitors()
            cameraStatusItem?.button?.highlight(true)
            startAutoCloseTimer()
            return
        }

        guard window.isVisible else { return }
        if isStreamMode, let cameraId = activeCameraId, let saved = savedFrame(for: cameraId) {
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
        // Activate the app so the first click in the panel reaches the camera tile.
        // Without this, if the user previously clicked outside the app (losing active
        // status) the first click in the reopened panel is consumed by the system's
        // "activate app" gesture and only the second click registers.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        setupDismissMonitors()
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
            guard let self = self else { return }
            self.cancelAutoCloseTimer()
            if self.isStreamModeActive {
                self.saveCurrentFrame()
            } else if let window = self.cameraPanelWindow {
                // A corner drag in grid mode becomes the new grid size
                self.savedGridSize = window.frame.size
                self.cameraPanelSize = window.frame.size
                self.lastGridSize = window.frame.size
                self.recenterUnderStatusItem(window)
            }
            // Apply a resize that arrived mid-drag (e.g. a doorbell stream)
            if let pending = self.pendingResize {
                self.pendingResize = nil
                self.resizeCameraPanel(width: pending.width, height: pending.height,
                                       aspectRatio: pending.aspectRatio,
                                       isStream: pending.isStream, animated: pending.animated)
            }
        }

        // The grid hangs off the status item like a dropdown: while the user
        // drags a corner, keep it horizontally centered on the item and its
        // top edge pinned under the menu bar (origin-only moves are safe
        // during live resize; size changes are not).
        liveResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: cameraWindow,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.isStreamModeActive,
                  let window = self.cameraPanelWindow, window.inLiveResize else { return }
            self.recenterUnderStatusItem(window)
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
        if pendingAutoOpenShow {
            pendingAutoOpenShow = false
            pendingCameraPanelShow = false
            // Don't show yet — keep hidden until stream resize arrives with correct dimensions.
            // Unhide the iOS content so the view controller lifecycle runs (panelDidShow -> startStream).
            delegate?.cameraPanelManagerSetCameraWindowHidden(self, hidden: false)
            pendingAutoOpenReveal = true
        } else if pendingCameraPanelShow {
            pendingCameraPanelShow = false
            showCameraPanel()
        }
    }

    /// Re-anchors the grid panel to the status item: horizontally centered on
    /// the button, top edge 4pt below the menu bar. Origin-only, so it is
    /// safe to call from inside a live resize.
    private func recenterUnderStatusItem(_ window: NSWindow) {
        guard let button = cameraStatusItem?.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let visibleFrame = screen.visibleFrame
        let size = window.frame.size

        var x = screenRect.midX - size.width / 2
        x = max(visibleFrame.minX, min(x, visibleFrame.maxX - size.width))
        let origin = NSPoint(x: x, y: screenRect.minY - size.height - 4)
        if window.frame.origin != origin {
            window.setFrameOrigin(origin)
        }
    }

    private func positionCameraPanelWithSize(_ window: NSWindow, width: CGFloat, height: CGFloat, animate: Bool = false) {
        guard !window.inLiveResize,
              let button = cameraStatusItem?.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let visibleFrame = screen.visibleFrame

        // Never exceed the screen: content taller than the visible area
        // scrolls inside the panel instead of growing the window (setFrame
        // beyond the scene's size restrictions crashes).
        let width = min(width, visibleFrame.width)
        let height = min(height, screenRect.minY - 4 - visibleFrame.minY)

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
        // Same live-resize invariant as every other setFrame path.
        guard !window.inLiveResize, let screen = NSScreen.main else { return }
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

    // MARK: - Dismiss monitors (click outside, Esc)

    private func isPointInsidePanelOrStatusButton(_ screenPoint: NSPoint) -> Bool {
        if let panel = cameraPanelWindow, panel.frame.contains(screenPoint) {
            return true
        }
        if let button = cameraStatusItem?.button, let btnWindow = button.window {
            let btnRect = button.convert(button.bounds, to: nil)
            let btnScreenRect = btnWindow.convertToScreen(btnRect)
            if btnScreenRect.contains(screenPoint) {
                return true
            }
        }
        return false
    }

    private func setupDismissMonitors() {
        removeDismissMonitors()

        let dismissCheck: () -> Void = { [weak self] in
            guard let self = self else { return }
            let screenPoint = NSEvent.mouseLocation
            if self.isPointInsidePanelOrStatusButton(screenPoint) { return }
            self.dismissCameraPanel()
        }

        // Catch clicks outside the app
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            dismissCheck()
        }

        // Catch clicks on other windows within the app (e.g. settings window)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.cameraPanelWindow?.isVisible == true else { return event }
            // Identity check first — reliable signal for the status-bar button (the
            // geometric check can miss it because event.window for status-item clicks
            // isn't always the button's host window) and for the panel itself.
            if event.window == self.cameraPanelWindow { return event }
            if event.window == self.cameraStatusItem?.button?.window { return event }
            // Geometric check — catches clicks landing on child/hosted windows of the panel.
            let screenPoint: NSPoint
            if let eventWindow = event.window {
                screenPoint = eventWindow.convertPoint(toScreen: event.locationInWindow)
            } else {
                screenPoint = NSEvent.mouseLocation
            }
            if self.isPointInsidePanelOrStatusButton(screenPoint) { return event }
            self.dismissCameraPanel()
            return event
        }

        // Close on Esc, like a regular menu. The monitor only exists while the
        // panel is shown unpinned, so a pinned window keeps normal key handling.
        escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.cameraPanelWindow?.isVisible == true,
                  event.keyCode == 53 else { return event }
            self.dismissCameraPanel()
            return nil
        }
    }

    private func removeDismissMonitors() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        if let monitor = escKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escKeyMonitor = nil
        }
    }
}
