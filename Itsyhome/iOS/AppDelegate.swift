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

        // Initialize HomeKit manager
        homeKitManager = HomeKitManager()
        startupLog.info("[iOS] HomeKitManager created")

        // Load macOS plugin on Catalyst
        #if targetEnvironment(macCatalyst)
        loadMacOSPlugin()
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
        macOSController?.iOSBridge = homeKitManager
        homeKitManager?.macOSDelegate = macOSController

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
}
