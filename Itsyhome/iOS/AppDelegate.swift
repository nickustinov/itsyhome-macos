//
//  AppDelegate.swift
//  Itsyhome
//
//  Main iOS app delegate - initializes HomeKit and loads macOS plugin
//

import UIKit
import HomeKit
import os.log

private let startupLog = Logger(subsystem: "com.nickustinov.itsyhome", category: "Startup")

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var homeKitManager: HomeKitManager?
    var macOSController: iOS2Mac?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        startupLog.info("[iOS] Application didFinishLaunching")

        // Only initialize HomeKit manager if HomeKit is the selected platform
        if PlatformManager.shared.selectedPlatform == .homeKit {
            homeKitManager = HomeKitManager()
            startupLog.info("[iOS] HomeKitManager created")
        } else {
            startupLog.info("[iOS] Skipping HomeKitManager - using Home Assistant")
        }

        // Load macOS plugin on Catalyst
        #if targetEnvironment(macCatalyst)
        loadMacOSPlugin()
        setupCameraWindowNotifications()
        #endif

        return true
    }

    #if targetEnvironment(macCatalyst)
    private func loadMacOSPlugin() {
        startupLog.info("[iOS] Loading macOS plugin...")
        let bundleFileName = "macOSBridge.bundle"

        // Try PlugIns folder first, then Resources (xcodegen puts it in Resources)
        var bundleURL: URL?

        if let pluginsURL = Bundle.main.builtInPlugInsURL {
            let pluginsPath = pluginsURL.appendingPathComponent(bundleFileName)
            if FileManager.default.fileExists(atPath: pluginsPath.path) {
                bundleURL = pluginsPath
                startupLog.info("[iOS] Found plugin in PlugIns folder")
            }
        }

        if bundleURL == nil, let resourcesURL = Bundle.main.resourceURL {
            let resourcesPath = resourcesURL.appendingPathComponent(bundleFileName)
            if FileManager.default.fileExists(atPath: resourcesPath.path) {
                bundleURL = resourcesPath
                startupLog.info("[iOS] Found plugin in Resources folder")
            }
        }

        guard let bundleURL = bundleURL else {
            startupLog.error("[iOS] Plugin bundle not found in PlugIns or Resources")
            return
        }

        guard let bundle = Bundle(url: bundleURL) else {
            startupLog.error("[iOS] Failed to create bundle from URL: \(bundleURL.path, privacy: .public)")
            return
        }

        guard let pluginClass = bundle.principalClass as? iOS2Mac.Type else {
            startupLog.error("[iOS] Failed to get principalClass as iOS2Mac.Type — principalClass: \(String(describing: bundle.principalClass), privacy: .public)")
            return
        }

        macOSController = pluginClass.init()
        startupLog.info("[iOS] MacOSController instantiated")

        // Connect HomeKit if available
        if let homeKitManager = homeKitManager {
            macOSController?.iOSBridge = homeKitManager
            homeKitManager.macOSDelegate = macOSController
            startupLog.info("[iOS] HomeKit bridge connected")
        }

        startupLog.info("[iOS] macOSBridge plugin loaded and connected")
    }
    #endif
    
    // MARK: - UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let cameraActivityType = "com.nickustinov.itsyhome.camera"
        let isCamera = options.userActivities.contains { $0.activityType == cameraActivityType }

        if isCamera {
            return UISceneConfiguration(name: "Camera Configuration", sessionRole: connectingSceneSession.role)
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: - Camera window notifications (HA bridge)

    #if targetEnvironment(macCatalyst)
    private func setupCameraWindowNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRequestOpenCameraWindow),
            name: .requestOpenCameraWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRequestCloseCameraWindow),
            name: .requestCloseCameraWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRequestSetCameraWindowHidden(_:)),
            name: .requestSetCameraWindowHidden,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHACameraDataUpdated(_:)),
            name: NSNotification.Name("HACameraDataUpdated"),
            object: nil
        )
    }

    @objc private func handleHACameraDataUpdated(_ notification: Notification) {
        guard let jsonData = notification.userInfo?["camerasJSON"] as? Data,
              let cameras = try? JSONDecoder().decode([CameraData].self, from: jsonData) else {
            NSLog("[CameraDebug] AppDelegate: failed to decode cameras from notification")
            return
        }
        NSLog("[CameraDebug] AppDelegate: cached %d HA cameras", cameras.count)
        CameraViewController.cachedHACameras = cameras
    }

    @objc private func handleRequestOpenCameraWindow() {
        let activityType = "com.nickustinov.itsyhome.camera"
        let existingSession = UIApplication.shared.openSessions.first { session in
            session.configuration.name == "Camera Configuration"
        }

        let activity = NSUserActivity(activityType: activityType)
        activity.title = "Cameras"

        UIApplication.shared.requestSceneSessionActivation(
            existingSession,
            userActivity: activity,
            options: nil,
            errorHandler: { error in
                print("[CameraPanel] HA scene activation error: \(error.localizedDescription)")
            }
        )
    }

    @objc private func handleRequestCloseCameraWindow() {
        guard let session = UIApplication.shared.openSessions.first(where: {
            $0.configuration.name == "Camera Configuration"
        }) else { return }
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil, errorHandler: nil)
    }

    @objc private func handleRequestSetCameraWindowHidden(_ notification: Notification) {
        let hidden = notification.userInfo?["hidden"] as? Bool ?? true
        let cameraScenes = UIApplication.shared.connectedScenes.compactMap { scene -> UIWindowScene? in
            guard let windowScene = scene as? UIWindowScene else { return nil }
            guard windowScene.session.configuration.name == "Camera Configuration" else { return nil }
            return windowScene
        }

        for windowScene in cameraScenes {
            for window in windowScene.windows {
                window.isHidden = hidden
            }
        }

        if hidden {
            NotificationCenter.default.post(name: .cameraPanelDidHide, object: nil)
        } else {
            NotificationCenter.default.post(name: .cameraPanelDidShow, object: nil)
        }
    }
    #endif
}
